#import "KLRuleEngine.h"
#import "KLHttp.h"
#import "KLStore.h"
#import <libxml/HTMLparser.h>
#import <libxml/xpath.h>
#import <libxml/xpathInternals.h>

static NSError *KLRuleError(NSString *message, NSInteger code) {
    return [NSError errorWithDomain:@"KLRuleEngine" code:code userInfo:@{NSLocalizedDescriptionKey: message ?: @"规则解析失败"}];
}

@interface KLRuleEngine ()
@end

@implementation KLRuleEngine

+ (instancetype)shared {
    static KLRuleEngine *engine = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ engine = [[KLRuleEngine alloc] init]; });
    return engine;
}

#pragma mark - URL helpers

- (NSString *)fullURLForRule:(KLRule *)rule path:(NSString *)path {
    if (!path.length) return @"";
    NSString *p = [path stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([p hasPrefix:@"http://"] || [p hasPrefix:@"https://"]) return p;
    if ([p hasPrefix:@"//"]) return [@"https:" stringByAppendingString:p];
    NSString *base = rule.baseURL ?: @"";
    if ([p hasPrefix:@"/"]) {
        NSURL *u = [NSURL URLWithString:base];
        if (u.scheme && u.host) return [NSString stringWithFormat:@"%@://%@%@", u.scheme, u.host, p];
        return p;
    }
    if (![base hasSuffix:@"/"]) base = [base stringByAppendingString:@"/"];
    return [base stringByAppendingString:p];
}

- (NSString *)replaceVariables:(NSString *)template variables:(NSDictionary *)variables {
    NSString *result = template ?: @"";
    for (NSString *key in variables) {
        id value = variables[key];
        NSString *s = [value isKindOfClass:[NSString class]] ? value : [value description];
        result = [result stringByReplacingOccurrencesOfString:[@"@" stringByAppendingString:key] withString:s ?: @""];
    }
    return result;
}

- (NSString *)buildEpisodePageURL:(KLRule *)rule source:(NSString *)source episodeURL:(NSString *)episodeURL variables:(NSDictionary *)vars {
    NSDictionary *page = rule.chapterApiConfig[@"episodePage"];
    if (![page isKindOfClass:[NSDictionary class]]) return [self fullURLForRule:rule path:episodeURL];
    NSMutableDictionary *all = [NSMutableDictionary dictionary];
    if (vars) [all addEntriesFromDictionary:vars];
    all[@"source"] = source ?: @"";
    all[@"episodeUrl"] = episodeURL ?: @"";
    all[@"episodeURL"] = episodeURL ?: @"";
    NSString *url = [self replaceVariables:page[@"url"] ?: @"" variables:all];
    url = [self fullURLForRule:rule path:url];
    NSDictionary *query = page[@"query"];
    if ([query isKindOfClass:[NSDictionary class]] && query.count) {
        NSMutableArray *pairs = [NSMutableArray array];
        for (NSString *key in query) {
            NSString *value = [self replaceVariables:[query[key] description] variables:all];
            [pairs addObject:[NSString stringWithFormat:@"%@=%@", [KLHttp encode:key], [KLHttp encode:value]]];
        }
        if (pairs.count) url = [url stringByAppendingFormat:@"%@%@", [url containsString:@"?"] ? @"&" : @"?", [pairs componentsJoinedByString:@"&"]];
    }
    return url;
}

#pragma mark - XPath helpers

- (NSString *)normalizeXPath:(NSString *)expression relative:(BOOL)relative {
    NSString *e = [expression stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (e.length == 0) return @"";
    if ([e isEqualToString:@"."]) return @".";
    if (relative && [e hasPrefix:@"//"]) return [@"." stringByAppendingString:e];
    return e;
}

- (NSArray *)evaluateXPath:(NSString *)expression context:(xmlNodePtr)context doc:(htmlDocPtr)doc {
    if (!expression.length) return @[];
    xmlXPathContextPtr ctx = xmlXPathNewContext(doc);
    if (!ctx) return @[];
    if (context) ctx->node = context;
    NSString *expr = [self normalizeXPath:expression relative:(context != NULL)];
    xmlXPathObjectPtr obj = xmlXPathEvalExpression((const xmlChar *)[expr UTF8String], ctx);
    NSMutableArray *nodes = [NSMutableArray array];
    if (obj && obj->type == XPATH_NODESET && obj->nodesetval) {
        for (int i = 0; i < obj->nodesetval->nodeNr; i++) {
            xmlNodePtr node = obj->nodesetval->nodeTab[i];
            if (node) [nodes addObject:[NSValue valueWithPointer:node]];
        }
    }
    if (obj) xmlXPathFreeObject(obj);
    xmlXPathFreeContext(ctx);
    return nodes;
}

- (NSString *)stringForXPath:(NSString *)expression context:(xmlNodePtr)context doc:(htmlDocPtr)doc {
    if (!expression.length) return @"";
    xmlXPathContextPtr ctx = xmlXPathNewContext(doc);
    if (!ctx) return @"";
    if (context) ctx->node = context;
    NSString *expr = [self normalizeXPath:expression relative:(context != NULL)];
    xmlXPathObjectPtr obj = xmlXPathEvalExpression((const xmlChar *)[expr UTF8String], ctx);
    NSString *result = @"";
    if (obj) {
        if (obj->type == XPATH_STRING && obj->stringval) {
            result = [NSString stringWithUTF8String:(const char *)obj->stringval] ?: @"";
        } else if (obj->type == XPATH_NODESET && obj->nodesetval) {
            NSMutableString *combined = [NSMutableString string];
            for (int i = 0; i < obj->nodesetval->nodeNr; i++) {
                xmlNodePtr n = obj->nodesetval->nodeTab[i];
                if (!n) continue;
                xmlChar *content = xmlNodeGetContent(n);
                if (content) {
                    NSString *s = [NSString stringWithUTF8String:(const char *)content] ?: @"";
                    [combined appendString:s];
                    xmlFree(content);
                }
            }
            result = combined;
        }
        xmlXPathFreeObject(obj);
    }
    xmlXPathFreeContext(ctx);
    return [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)attributeForXPath:(NSString *)expression context:(xmlNodePtr)context doc:(htmlDocPtr)doc attribute:(NSString *)attribute {
    if (!expression.length) return @"";
    NSArray *nodes = [self evaluateXPath:expression context:context doc:doc];
    for (NSValue *v in nodes) {
        xmlNodePtr node = [v pointerValue];
        if (!node) continue;
        if (node->type == XML_ATTRIBUTE_NODE) {
            xmlChar *content = xmlNodeGetContent(node);
            NSString *s = content ? ([NSString stringWithUTF8String:(const char *)content] ?: @"") : @"";
            if (content) xmlFree(content);
            if (s.length) return s;
        }
        xmlChar *attr = xmlGetProp(node, (const xmlChar *)[attribute UTF8String]);
        if (attr) {
            NSString *s = [NSString stringWithUTF8String:(const char *)attr] ?: @"";
            xmlFree(attr);
            if (s.length) return s;
        }
    }
    return @"";
}

- (htmlDocPtr)documentFromData:(NSData *)data {
    if (data.length == 0) return NULL;
    return htmlReadMemory((const char *)data.bytes, (int)data.length, NULL, NULL,
                          HTML_PARSE_RECOVER | HTML_PARSE_NOERROR | HTML_PARSE_NOWARNING | HTML_PARSE_NONET);
}

- (NSString *)textOfNode:(xmlNodePtr)node {
    if (!node) return @"";
    xmlChar *content = xmlNodeGetContent(node);
    NSString *s = content ? ([NSString stringWithUTF8String:(const char *)content] ?: @"") : @"";
    if (content) xmlFree(content);
    return [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

#pragma mark - JSONPath lite

- (NSArray *)evaluateJSONPath:(NSString *)path root:(id)root {
    if (!path.length || root == nil) return @[];
    NSString *p = [path stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([p isEqualToString:@"$"]) return @[root];
    if ([p hasPrefix:@"$."]) p = [p substringFromIndex:2];
    else if ([p hasPrefix:@"$"]) p = [p substringFromIndex:1];

    NSMutableArray *tokens = [NSMutableArray array];
    NSMutableString *token = [NSMutableString string];
    for (NSUInteger i = 0; i < p.length; i++) {
        unichar c = [p characterAtIndex:i];
        if (c == '.') {
            if (token.length) { [tokens addObject:token]; [token setString:@""]; }
        } else if (c == '[') {
            if (token.length) { [tokens addObject:token]; [token setString:@""]; }
            NSRange close = [p rangeOfString:@"]" options:0 range:NSMakeRange(i, p.length - i)];
            if (close.location == NSNotFound) break;
            NSString *inner = [p substringWithRange:NSMakeRange(i + 1, close.location - i - 1)];
            [tokens addObject:[NSString stringWithFormat:@"[%@]", inner]];
            i = close.location;
        } else {
            [token appendFormat:@"%C", c];
        }
    }
    if (token.length) [tokens addObject:token];

    NSArray *current = @[root];
    for (NSString *t in tokens) {
        NSMutableArray *next = [NSMutableArray array];
        if ([t hasPrefix:@"["]) {
            NSString *inner = [t substringWithRange:NSMakeRange(1, t.length - 2)];
            if ([inner isEqualToString:@"*"]) {
                for (id value in current) {
                    if ([value isKindOfClass:[NSArray class]]) [next addObjectsFromArray:value];
                    else if ([value isKindOfClass:[NSDictionary class]]) [next addObjectsFromArray:[value allValues]];
                    else [next addObject:value];
                }
            } else {
                NSInteger idx = [inner integerValue];
                for (id value in current) {
                    if ([value isKindOfClass:[NSArray class]] && idx >= 0 && idx < [value count]) [next addObject:value[idx]];
                }
            }
        } else {
            for (id value in current) {
                if ([value isKindOfClass:[NSDictionary class]]) {
                    id v = value[t];
                    if (v) [next addObject:v];
                } else if ([value isKindOfClass:[NSArray class]]) {
                    for (id child in value) if ([child isKindOfClass:[NSDictionary class]] && child[t]) [next addObject:child[t]];
                }
            }
        }
        current = next;
    }
    // Flatten one level of arrays so callers get the expected leaf list.
    NSMutableArray *flat = [NSMutableArray array];
    for (id v in current) {
        if ([v isKindOfClass:[NSArray class]]) [flat addObjectsFromArray:v];
        else [flat addObject:v];
    }
    return flat;
}

- (NSString *)stringFromJSONPath:(NSString *)path root:(id)root {
    NSArray *values = [self evaluateJSONPath:path root:root];
    if (values.count == 0) return @"";
    id v = values.firstObject;
    if ([v isKindOfClass:[NSString class]]) return v;
    if ([v isKindOfClass:[NSNumber class]]) return [v stringValue];
    if ([v isKindOfClass:[NSNull class]]) return @"";
    return [v description];
}

#pragma mark - Requests

- (void)fetchTextForRule:(KLRule *)rule
                     url:(NSString *)url
                  method:(NSString *)method
                 headers:(NSDictionary *)headers
                    body:(NSData *)body
              completion:(void (^)(NSString *text, NSData *data, NSError *error))completion {
    NSMutableDictionary *h = [NSMutableDictionary dictionary];
    h[@"Referer"] = rule.referer.length ? rule.referer : (rule.baseURL.length ? rule.baseURL : url);
    if (rule.userAgent.length) h[@"User-Agent"] = rule.userAgent;
    if (headers) [h addEntriesFromDictionary:headers];
    [KLHttp requestURL:url method:method headers:h body:body completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *error) {
        if (error && data.length == 0) {
            if (completion) completion(nil, data, error);
            return;
        }
        NSString *text = nil;
        if ([json isKindOfClass:[NSString class]]) text = json;
        else if (data.length) {
            text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (!text) text = [[NSString alloc] initWithData:data encoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000)];
        }
        if (!text.length) {
            if (completion) completion(nil, data, error ?: KLRuleError(@"响应为空", -3));
            return;
        }
        if (completion) completion(text, data, error);
    }];
}

#pragma mark - Search

- (void)searchWithRule:(KLRule *)rule keyword:(NSString *)keyword completion:(void (^)(NSArray *, NSError *))completion {
    if (!rule) {
        if (completion) completion(nil, KLRuleError(@"规则不存在", -1));
        return;
    }
    if ([rule isAPISearch]) {
        [self apiSearch:rule keyword:keyword completion:completion];
    } else {
        [self xpathSearch:rule keyword:keyword completion:completion];
    }
}

- (void)xpathSearch:(KLRule *)rule keyword:(NSString *)keyword completion:(void (^)(NSArray *, NSError *))completion {
    NSString *urlTemplate = rule.searchURL ?: @"";
    if (urlTemplate.length == 0) {
        if (completion) completion(nil, KLRuleError(@"该规则未配置搜索地址，可直接粘贴链接解析", -10));
        return;
    }
    NSString *url = [urlTemplate stringByReplacingOccurrencesOfString:@"@keyword" withString:[KLHttp encode:keyword ?: @""]];
    NSString *method = @"GET";
    NSData *body = nil;
    NSDictionary *headers = nil;
    if (rule.usePost) {
        NSRange q = [url rangeOfString:@"?"];
        NSString *query = q.location == NSNotFound ? @"" : [url substringFromIndex:q.location + 1];
        url = q.location == NSNotFound ? url : [url substringToIndex:q.location];
        method = @"POST";
        headers = @{@"Content-Type": @"application/x-www-form-urlencoded; charset=UTF-8"};
        body = [query dataUsingEncoding:NSUTF8StringEncoding];
    }
    [self fetchTextForRule:rule url:url method:method headers:headers body:body completion:^(NSString *text, NSData *data, NSError *error) {
        if (!text.length) {
            if (completion) completion(nil, error ?: KLRuleError(@"搜索请求失败", -11));
            return;
        }
        htmlDocPtr doc = [self documentFromData:[text dataUsingEncoding:NSUTF8StringEncoding] ?: data];
        if (!doc) {
            if (completion) completion(nil, KLRuleError(@"HTML 解析失败", -12));
            return;
        }
        NSArray *nodes = [self evaluateXPath:rule.searchList context:NULL doc:doc];
        NSMutableArray *items = [NSMutableArray array];
        for (NSValue *v in nodes) {
            xmlNodePtr node = [v pointerValue];
            if (!node) continue;
            NSString *name = [self stringForXPath:rule.searchName context:node doc:doc];
            NSString *src = [self attributeForXPath:rule.searchResult context:node doc:doc attribute:@"href"];
            if (src.length == 0 && ([rule.searchResult isEqualToString:@"."] || rule.searchResult.length == 0)) {
                src = [self attributeForXPath:@"." context:node doc:doc attribute:@"href"];
            }
            if (name.length == 0 || src.length == 0) continue;
            KLSearchItem *item = [[KLSearchItem alloc] init];
            item.name = name;
            item.src = [self fullURLForRule:rule path:src];
            item.ruleName = rule.name;
            [items addObject:item];
        }
        xmlFreeDoc(doc);
        if (items.count == 0) {
            if (completion) completion(nil, KLRuleError(@"未找到搜索结果（可能需要验证码或规则已失效）", -13));
            return;
        }
        if (completion) completion(items, nil);
    }];
}

- (void)apiSearch:(KLRule *)rule keyword:(NSString *)keyword completion:(void (^)(NSArray *, NSError *))completion {
    NSDictionary *config = rule.searchApiConfig;
    NSDictionary *request = config[@"request"];
    if (![request isKindOfClass:[NSDictionary class]]) {
        if (completion) completion(nil, KLRuleError(@"API 搜索配置缺失", -20));
        return;
    }
    NSDictionary *vars = @{@"keyword": keyword ?: @""};
    NSString *url = [self replaceVariables:request[@"url"] ?: @"" variables:vars];
    url = [self fullURLForRule:rule path:url];
    NSDictionary *query = request[@"query"];
    if ([query isKindOfClass:[NSDictionary class]] && query.count) {
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        for (NSString *key in query) params[key] = [self replaceVariables:[query[key] description] variables:vars];
        url = [KLHttp appendQuery:params toURL:url];
    }
    NSString *method = [request[@"method"] uppercaseString] ?: @"GET";
    NSDictionary *headers = [request[@"headers"] isKindOfClass:[NSDictionary class]] ? request[@"headers"] : nil;
    NSData *body = nil;
    NSString *bodyType = config[@"bodyType"] ?: request[@"bodyType"];
    id bodyObject = request[@"body"];
    if ([method isEqualToString:@"POST"] && bodyObject) {
        if ([bodyType isEqualToString:@"form"]) {
            NSMutableDictionary *params = [NSMutableDictionary dictionary];
            if ([bodyObject isKindOfClass:[NSDictionary class]]) {
                for (NSString *k in bodyObject) params[k] = [self replaceVariables:[bodyObject[k] description] variables:vars];
            }
            body = [[KLHttp queryString:params] dataUsingEncoding:NSUTF8StringEncoding];
            NSMutableDictionary *h = [NSMutableDictionary dictionaryWithDictionary:headers ?: @{}];
            h[@"Content-Type"] = @"application/x-www-form-urlencoded";
            headers = h;
        } else {
            body = [self JSONDataWithTemplate:bodyObject variables:vars];
            NSMutableDictionary *h = [NSMutableDictionary dictionaryWithDictionary:headers ?: @{}];
            h[@"Content-Type"] = @"application/json; charset=utf-8";
            headers = h;
        }
    }
    [self fetchTextForRule:rule url:url method:method headers:headers body:body completion:^(NSString *text, NSData *data, NSError *error) {
        if (!text.length) {
            if (completion) completion(nil, error ?: KLRuleError(@"API 搜索请求失败", -21));
            return;
        }
        id json = [NSJSONSerialization JSONObjectWithData:[text dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
        if (!json) {
            if (completion) completion(nil, KLRuleError(@"API 响应不是 JSON", -22));
            return;
        }
        NSString *listPath = config[@"listPath"] ?: @"$.data[*]";
        NSString *namePath = config[@"namePath"] ?: @"$.name";
        NSString *sourcePath = config[@"sourcePath"] ?: @"$.url";
        NSString *sourceTemplate = config[@"sourceTemplate"] ?: @"";
        NSArray *rows = [self evaluateJSONPath:listPath root:json];
        NSMutableArray *items = [NSMutableArray array];
        for (id row in rows) {
            NSString *name = [self stringFromJSONPath:namePath root:row];
            NSString *source = [self stringFromJSONPath:sourcePath root:row];
            if (name.length == 0 || source.length == 0) continue;
            if (sourceTemplate.length) {
                source = [sourceTemplate stringByReplacingOccurrencesOfString:@"@source" withString:source];
            }
            KLSearchItem *item = [[KLSearchItem alloc] init];
            item.name = name;
            item.src = [self fullURLForRule:rule path:source];
            item.ruleName = rule.name;
            [items addObject:item];
        }
        if (items.count == 0) {
            if (completion) completion(nil, KLRuleError(@"未找到搜索结果", -23));
            return;
        }
        if (completion) completion(items, nil);
    }];
}

- (NSData *)JSONDataWithTemplate:(id)template variables:(NSDictionary *)vars {
    id replaced = [self replaceInObject:template variables:vars];
    return [NSJSONSerialization dataWithJSONObject:replaced options:0 error:NULL];
}

- (id)replaceInObject:(id)object variables:(NSDictionary *)vars {
    if ([object isKindOfClass:[NSString class]]) return [self replaceVariables:object variables:vars];
    if ([object isKindOfClass:[NSArray class]]) {
        NSMutableArray *arr = [NSMutableArray array];
        for (id v in object) [arr addObject:[self replaceInObject:v variables:vars]];
        return arr;
    }
    if ([object isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        for (NSString *k in object) dict[k] = [self replaceInObject:object[k] variables:vars];
        return dict;
    }
    return object ?: @"";
}

#pragma mark - Chapters

- (void)chaptersWithRule:(KLRule *)rule source:(NSString *)source completion:(void (^)(NSArray *, NSError *))completion {
    if (!rule) {
        if (completion) completion(nil, KLRuleError(@"规则不存在", -1));
        return;
    }
    if ([rule isAPIChapter]) [self apiChapters:rule source:source completion:completion];
    else [self xpathChapters:rule source:source completion:completion];
}

- (void)xpathChapters:(KLRule *)rule source:(NSString *)source completion:(void (^)(NSArray *, NSError *))completion {
    NSString *url = [self fullURLForRule:rule path:source];
    [self fetchTextForRule:rule url:url method:@"GET" headers:nil body:nil completion:^(NSString *text, NSData *data, NSError *error) {
        if (!text.length) {
            if (completion) completion(nil, error ?: KLRuleError(@"章节页面请求失败", -30));
            return;
        }
        htmlDocPtr doc = [self documentFromData:[text dataUsingEncoding:NSUTF8StringEncoding] ?: data];
        if (!doc) {
            if (completion) completion(nil, KLRuleError(@"章节 HTML 解析失败", -31));
            return;
        }
        NSArray *roadNodes = [self evaluateXPath:rule.chapterRoads context:NULL doc:doc];
        NSMutableArray *roads = [NSMutableArray array];
        for (NSValue *rv in roadNodes) {
            xmlNodePtr roadNode = [rv pointerValue];
            NSArray *eps = [self evaluateXPath:rule.chapterResult context:roadNode doc:doc];
            NSMutableArray *urls = [NSMutableArray array];
            NSMutableArray *names = [NSMutableArray array];
            for (NSValue *ev in eps) {
                xmlNodePtr ep = [ev pointerValue];
                NSString *href = [self attributeForXPath:@"." context:ep doc:doc attribute:@"href"];
                if (href.length == 0) href = [self attributeForXPath:@"a" context:ep doc:doc attribute:@"href"];
                if (href.length == 0) continue;
                NSString *name = [self textOfNode:ep];
                if (name.length == 0) name = [self stringForXPath:@".//text()" context:ep doc:doc];
                [urls addObject:[self fullURLForRule:rule path:href]];
                [names addObject:name.length ? name : [NSString stringWithFormat:@"第%ld集", (long)urls.count]];
            }
            if (urls.count == 0) continue;
            KLRoad *road = [[KLRoad alloc] init];
            road.name = [NSString stringWithFormat:@"播放线路%ld", (long)roads.count + 1];
            road.urls = urls;
            road.identifiers = names;
            [roads addObject:road];
        }
        xmlFreeDoc(doc);
        if (roads.count == 0) {
            if (completion) completion(nil, KLRuleError(@"未解析到播放线路", -32));
            return;
        }
        if (completion) completion(roads, nil);
    }];
}

- (void)apiChapters:(KLRule *)rule source:(NSString *)source completion:(void (^)(NSArray *, NSError *))completion {
    NSDictionary *config = rule.chapterApiConfig;
    NSDictionary *request = config[@"request"];
    if (![request isKindOfClass:[NSDictionary class]]) {
        if (completion) completion(nil, KLRuleError(@"API 章节配置缺失", -40));
        return;
    }
    NSDictionary *vars = @{@"source": source ?: @""};
    NSString *url = [self replaceVariables:request[@"url"] ?: @"" variables:vars];
    url = [self fullURLForRule:rule path:url];
    NSDictionary *query = request[@"query"];
    if ([query isKindOfClass:[NSDictionary class]] && query.count) {
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        for (NSString *key in query) params[key] = [self replaceVariables:[query[key] description] variables:vars];
        url = [KLHttp appendQuery:params toURL:url];
    }
    NSString *method = [request[@"method"] uppercaseString] ?: @"GET";
    NSDictionary *headers = [request[@"headers"] isKindOfClass:[NSDictionary class]] ? request[@"headers"] : nil;
    NSData *body = nil;
    if ([method isEqualToString:@"POST"] && request[@"body"]) {
        NSString *bodyType = config[@"bodyType"] ?: request[@"bodyType"];
        if ([bodyType isEqualToString:@"form"]) {
            NSMutableDictionary *params = [NSMutableDictionary dictionary];
            NSDictionary *b = request[@"body"];
            if ([b isKindOfClass:[NSDictionary class]]) for (NSString *k in b) params[k] = [self replaceVariables:[b[k] description] variables:vars];
            body = [[KLHttp queryString:params] dataUsingEncoding:NSUTF8StringEncoding];
            NSMutableDictionary *h = [NSMutableDictionary dictionaryWithDictionary:headers ?: @{}];
            h[@"Content-Type"] = @"application/x-www-form-urlencoded";
            headers = h;
        } else {
            body = [NSJSONSerialization dataWithJSONObject:[self replaceInObject:request[@"body"] variables:vars] options:0 error:NULL];
            NSMutableDictionary *h = [NSMutableDictionary dictionaryWithDictionary:headers ?: @{}];
            h[@"Content-Type"] = @"application/json; charset=utf-8";
            headers = h;
        }
    }
    [self fetchTextForRule:rule url:url method:method headers:headers body:body completion:^(NSString *text, NSData *data, NSError *error) {
        if (!text.length) {
            if (completion) completion(nil, error ?: KLRuleError(@"章节请求失败", -41));
            return;
        }
        id json = [NSJSONSerialization JSONObjectWithData:[text dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
        if (!json) {
            if (completion) completion(nil, KLRuleError(@"章节响应不是 JSON", -42));
            return;
        }
        NSMutableArray *roads = [NSMutableArray array];
        NSString *format = config[@"format"] ?: @"nested";
        NSMutableDictionary *variables = [NSMutableDictionary dictionary];
        NSDictionary *varPaths = config[@"variables"];
        if ([varPaths isKindOfClass:[NSDictionary class]]) {
            for (NSString *key in varPaths) variables[key] = [self stringFromJSONPath:varPaths[key] root:json];
        }
        if ([format isEqualToString:@"delimited"]) {
            NSArray *roadNames = [self evaluateJSONPath:config[@"roadNamesPath"] ?: @"" root:json];
            NSArray *roadStrings = [self evaluateJSONPath:config[@"roadEpisodesPath"] ?: @"" root:json];
            NSString *namesJoined = roadNames.count ? [roadNames.firstObject description] : @"";
            NSString *epsJoined = roadStrings.count ? [roadStrings.firstObject description] : @"";
            if (![namesJoined isKindOfClass:[NSString class]]) namesJoined = [namesJoined description] ?: @"";
            if (![epsJoined isKindOfClass:[NSString class]]) epsJoined = [epsJoined description] ?: @"";
            NSArray *nameParts = [namesJoined componentsSeparatedByString:config[@"roadSeparator"] ?: @"$$$"];
            NSArray *roadParts = [epsJoined componentsSeparatedByString:config[@"roadSeparator"] ?: @"$$$"];
            for (NSInteger i = 0; i < roadParts.count; i++) {
                NSString *epString = roadParts[i];
                if (![epString isKindOfClass:[NSString class]] || epString.length == 0) continue;
                NSArray *episodes = [epString componentsSeparatedByString:config[@"episodeSeparator"] ?: @"#"];
                NSMutableArray *urls = [NSMutableArray array];
                NSMutableArray *names = [NSMutableArray array];
                for (NSString *ep in episodes) {
                    NSArray *fields = [ep componentsSeparatedByString:config[@"fieldSeparator"] ?: @"$"];
                    if (fields.count == 0) continue;
                    NSString *epName = fields.count > 1 ? fields[0] : [NSString stringWithFormat:@"第%ld集", (long)urls.count + 1];
                    NSString *epURL = fields.count > 1 ? fields[1] : fields[0];
                    if (epURL.length == 0) continue;
                    [names addObject:epName];
                    [urls addObject:[self buildEpisodePageURL:rule source:source episodeURL:epURL variables:variables]];
                }
                if (urls.count == 0) continue;
                KLRoad *road = [[KLRoad alloc] init];
                road.name = i < nameParts.count && [nameParts[i] length] ? nameParts[i] : [NSString stringWithFormat:@"播放线路%ld", (long)roads.count + 1];
                road.urls = urls;
                road.identifiers = names;
                [roads addObject:road];
            }
        } else {
            NSArray *roadRows = [self evaluateJSONPath:config[@"roadsPath"] ?: @"$.data.roads[*]" root:json];
            for (id roadRow in roadRows) {
                NSString *roadName = [self stringFromJSONPath:config[@"roadNamePath"] ?: @"$.name" root:roadRow];
                NSArray *epRows = [self evaluateJSONPath:config[@"episodesPath"] ?: @"$.episodes[*]" root:roadRow];
                NSMutableArray *urls = [NSMutableArray array];
                NSMutableArray *names = [NSMutableArray array];
                for (id epRow in epRows) {
                    NSString *epName = [self stringFromJSONPath:config[@"episodeNamePath"] ?: @"$.name" root:epRow];
                    NSString *epURL = [self stringFromJSONPath:config[@"episodeUrlPath"] ?: @"$.url" root:epRow];
                    if (epURL.length == 0) continue;
                    [names addObject:epName.length ? epName : [NSString stringWithFormat:@"第%ld集", (long)urls.count + 1]];
                    [urls addObject:[self buildEpisodePageURL:rule source:source episodeURL:epURL variables:variables]];
                }
                if (urls.count == 0) continue;
                KLRoad *road = [[KLRoad alloc] init];
                road.name = roadName.length ? roadName : [NSString stringWithFormat:@"播放线路%ld", (long)roads.count + 1];
                road.urls = urls;
                road.identifiers = names;
                [roads addObject:road];
            }
        }
        if (roads.count == 0) {
            if (completion) completion(nil, KLRuleError(@"未解析到播放线路", -43));
            return;
        }
        if (completion) completion(roads, nil);
    }];
}

@end
