#import "KLDlnaController.h"
#import "KLHttp.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>
#import <string.h>

@implementation KLDlnaDevice
@end

@interface KLDlnaController ()
@end

@implementation KLDlnaController

+ (instancetype)shared {
    static KLDlnaController *c = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ c = [[KLDlnaController alloc] init]; });
    return c;
}

- (void)discover:(void (^)(NSArray *, NSError *))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int sock = socket(AF_INET, SOCK_DGRAM, 0);
        if (sock < 0) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(@[], [NSError errorWithDomain:@"KLDlna" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"无法创建 SSDP socket"}]); });
            return;
        }
        int yes = 1;
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
        struct timeval tv;
        tv.tv_sec = 0;
        tv.tv_usec = 400000;
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));

        struct sockaddr_in addr;
        memset(&addr, 0, sizeof(addr));
        addr.sin_family = AF_INET;
        addr.sin_port = htons(1900);
        addr.sin_addr.s_addr = inet_addr("239.255.255.250");
        const char *msg = "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nMX: 2\r\nST: urn:schemas-upnp-org:device:MediaRenderer:1\r\n\r\n";
        sendto(sock, msg, strlen(msg), 0, (struct sockaddr *)&addr, sizeof(addr));

        NSMutableSet *locations = [NSMutableSet set];
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:3.0];
        char buffer[4096];
        while ([deadline timeIntervalSinceNow] > 0) {
            struct sockaddr_in from;
            socklen_t fromLen = sizeof(from);
            ssize_t n = recvfrom(sock, buffer, sizeof(buffer) - 1, 0, (struct sockaddr *)&from, &fromLen);
            if (n <= 0) continue;
            buffer[n] = '\0';
            NSString *response = [NSString stringWithUTF8String:buffer];
            if (!response) continue;
            for (NSString *line in [response componentsSeparatedByString:@"\r\n"]) {
                if ([line.lowercaseString hasPrefix:@"location:"]) {
                    NSString *loc = [[line substringFromIndex:9] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    if (loc.length) [locations addObject:loc];
                }
            }
        }
        close(sock);

        if (locations.count == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(@[], [NSError errorWithDomain:@"KLDlna" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"没有发现 DLNA 设备，请确认电视与手机在同一 Wi-Fi"}]); });
            return;
        }
        NSMutableArray *devices = [NSMutableArray array];
        __block NSInteger pending = locations.count;
        for (NSString *location in locations) {
            [KLHttp GET:location headers:nil completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *error) {
                NSString *xml = [json isKindOfClass:[NSString class]] ? json : [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                if (xml.length) {
                    KLDlnaDevice *device = [self parseDeviceXML:xml location:location];
                    if (device) @synchronized (devices) { [devices addObject:device]; }
                }
                @synchronized (devices) {
                    pending--;
                    if (pending <= 0) {
                        dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion([devices copy], nil); });
                    }
                }
            }];
        }
    });
}

- (KLDlnaDevice *)parseDeviceXML:(NSString *)xml location:(NSString *)location {
    NSRegularExpression *nameRe = [NSRegularExpression regularExpressionWithPattern:@"<friendlyName>([^<]*)</friendlyName>" options:0 error:NULL];
    NSTextCheckingResult *nameMatch = [nameRe firstMatchInString:xml options:0 range:NSMakeRange(0, xml.length)];
    NSString *name = nameMatch ? [xml substringWithRange:[nameMatch rangeAtIndex:1]] : @"DLNA 设备";

    NSRange serviceRange = [xml rangeOfString:@"urn:schemas-upnp-org:service:AVTransport:1"];
    if (serviceRange.location == NSNotFound) return nil;
    NSString *tail = [xml substringFromIndex:serviceRange.location];
    NSRegularExpression *controlRe = [NSRegularExpression regularExpressionWithPattern:@"<controlURL>([^<]*)</controlURL>" options:0 error:NULL];
    NSTextCheckingResult *controlMatch = [controlRe firstMatchInString:tail options:0 range:NSMakeRange(0, tail.length)];
    if (!controlMatch) return nil;
    NSString *control = [[tail substringWithRange:[controlMatch rangeAtIndex:1]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (control.length == 0) return nil;
    if (![control hasPrefix:@"http"]) {
        if ([control hasPrefix:@"/"]) {
            NSURL *loc = [NSURL URLWithString:location];
            control = [NSString stringWithFormat:@"%@://%@%@", loc.scheme, loc.host, control];
        } else {
            control = [[location stringByDeletingLastPathComponent] stringByAppendingPathComponent:control];
        }
    }
    KLDlnaDevice *device = [[KLDlnaDevice alloc] init];
    device.name = name;
    device.location = location;
    device.controlURL = control;
    return device;
}

- (void)soapAction:(NSString *)action body:(NSString *)body device:(KLDlnaDevice *)device completion:(void (^)(BOOL, NSString *))completion {
    NSString *soap = [NSString stringWithFormat:
        @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"
        "<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">"
        "<s:Body>%@</s:Body></s:Envelope>", body];
    NSDictionary *headers = @{
        @"Content-Type": @"text/xml; charset=\"utf-8\"",
        @"SOAPACTION": [NSString stringWithFormat:@"\"urn:schemas-upnp-org:service:AVTransport:1#%@\"", action]
    };
    [KLHttp requestURL:device.controlURL method:@"POST" headers:headers body:[soap dataUsingEncoding:NSUTF8StringEncoding] completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *error) {
        BOOL ok = response.statusCode >= 200 && response.statusCode < 300;
        if (completion) completion(ok, ok ? @"成功" : (error.localizedDescription ?: [NSString stringWithFormat:@"HTTP %ld", (long)response.statusCode]));
    }];
}

- (void)castURL:(NSString *)url toDevice:(KLDlnaDevice *)device completion:(void (^)(BOOL, NSString *))completion {
    if (!device.controlURL.length || !url.length) {
        if (completion) completion(NO, @"设备或视频地址为空");
        return;
    }
    NSString *escaped = [url stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
    NSString *body = [NSString stringWithFormat:
        @"<u:SetAVTransportURI xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\">"
        "<InstanceID>0</InstanceID><CurrentURI>%@</CurrentURI><CurrentURIMetaData></CurrentURIMetaData>"
        "</u:SetAVTransportURI>", escaped];
    __weak typeof(self) weakSelf = self;
    [self soapAction:@"SetAVTransportURI" body:body device:device completion:^(BOOL ok, NSString *message) {
        if (!ok) { if (completion) completion(NO, message); return; }
        NSString *playBody = @"<u:Play xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\"><InstanceID>0</InstanceID><Speed>1</Speed></u:Play>";
        [weakSelf soapAction:@"Play" body:playBody device:device completion:completion];
    }];
}

- (void)stopDevice:(KLDlnaDevice *)device completion:(void (^)(BOOL, NSString *))completion {
    NSString *body = @"<u:Stop xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\"><InstanceID>0</InstanceID></u:Stop>";
    [self soapAction:@"Stop" body:body device:device completion:completion];
}

@end
