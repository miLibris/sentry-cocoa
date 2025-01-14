#import "SentryCrashReportSink.h"
#import "SentryAttachment.h"
#import "SentryClient.h"
#import "SentryCrash.h"
#import "SentryCrashReportConverter.h"
#import "SentryDefines.h"
#import "SentryEvent.h"
#import "SentryException.h"
#import "SentryHub.h"
#import "SentryLog.h"
#import "SentrySDK+Private.h"
#import "SentrySDK.h"
#import "SentryScope.h"
#import "SentryThread.h"

@interface
SentryCrashReportSink ()

@property (nonatomic, strong) SentryInAppLogic *inAppLogic;

@end

@implementation SentryCrashReportSink

- (instancetype)initWithInAppLogic:(SentryInAppLogic *)inAppLogic
{
    if (self = [super init]) {
        self.inAppLogic = inAppLogic;
    }
    return self;
}

- (void)handleConvertedEvent:(SentryEvent *)event
                      report:(NSDictionary *)report
                 sentReports:(NSMutableArray *)sentReports
{
    [sentReports addObject:report];
    SentryScope *scope = [[SentryScope alloc] initWithScope:SentrySDK.currentHub.scope];

    if (report[SENTRYCRASH_REPORT_ATTACHMENTS_ITEM]) {
        for (NSString *ssPath in report[SENTRYCRASH_REPORT_ATTACHMENTS_ITEM]) {
            [scope addAttachment:[[SentryAttachment alloc] initWithPath:ssPath]];
        }
    }

    [SentrySDK captureCrashEvent:event withScope:scope];
}

- (void)filterReports:(NSArray *)reports
         onCompletion:(SentryCrashReportFilterCompletion)onCompletion
{
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(queue, ^{
        NSMutableArray *sentReports = [NSMutableArray new];
        for (NSDictionary *report in reports) {
            SentryCrashReportConverter *reportConverter =
                [[SentryCrashReportConverter alloc] initWithReport:report
                                                        inAppLogic:self.inAppLogic];
            if (nil != [SentrySDK.currentHub getClient]) {
                SentryEvent *event = [reportConverter convertReportToEvent];
                if (nil != event) {
                    [self handleConvertedEvent:event report:report sentReports:sentReports];
                }
            } else {
                SENTRY_LOG_ERROR(
                    @"Crash reports were found but no [SentrySDK.currentHub getClient] is set. "
                    @"Cannot send crash reports to Sentry. This is probably a misconfiguration, "
                    @"make sure you set the client with [SentrySDK.currentHub bindClient] before "
                    @"calling startCrashHandlerWithError:.");
            }
        }
        if (onCompletion) {
            onCompletion(sentReports, TRUE, nil);
        }
    });
}

@end
