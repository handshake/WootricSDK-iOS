//
//  WTRSurveyViewController.m
//  WootricSDK
//
// Copyright (c) 2015 Wootric (https://wootric.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "WTRSurveyViewController.h"
#import "WTRSurveyViewController+Constraints.h"
#import "WTRSurveyViewController+Views.h"
#import "WTRColor.h"
#import "UIImage+ImageFromColor.h"
#import "WTRSurvey.h"
#import "WTRThankYouButton.h"
#import <Social/Social.h>

@interface WTRSurveyViewController ()

@property (nonatomic, assign) BOOL scrolled;
@property (nonatomic, assign) BOOL alreadyVoted;
@property (nonatomic, strong) CAGradientLayer *gradient;

@end

@implementation WTRSurveyViewController

- (instancetype)initWithSurveySettings:(WTRSettings *)settings {
  if (self = [super init]) {
    _gradient = [CAGradientLayer layer];
    _settings = settings;
    self.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    self.modalPresentationStyle = UIModalPresentationOverCurrentContext;
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  [self registerForKeyboardNotification];
  [self setupViews];
  [self setupConstraints];
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
}

- (void)viewDidAppear:(BOOL)animated {
  [UIView animateWithDuration:0.25 animations:^{
    self.view.backgroundColor = [WTRColor viewBackgroundColor];
    CGRect modalFrame = _modalView.frame;
    CGFloat modalPosition = self.view.frame.size.height - _modalView.frame.size.height;
    modalFrame.origin.y = modalPosition;
    _modalView.frame = modalFrame;
    _constraintTopToModalTop.constant = modalPosition;
  }];
  [self setModalGradient:_modalView.bounds];
  [_modalView.layer insertSublayer:_gradient atIndex:0];
  [_npsQuestionView addDotsAndScores];
}

#pragma mark - Button methods

- (void)openThankYouURL:(WTRThankYouButton *)sender {
  if (![[UIApplication sharedApplication] openURL:sender.buttonURL]) {
    NSLog(@"WootricSDK: Failed to open 'thank you' url");
  } else {
    [self dismissViewControllerWithBackgroundFade];
  }
}

- (void)editScoreButtonPressed:(UIButton *)sender {
  [_feedbackView textViewResignFirstResponder];
  _scrolled = NO;
  [self setQuestionViewVisible:YES andFeedbackViewVisible:NO];
}

- (void)dismissButtonPressed:(UIButton *)sender {
  if (!_alreadyVoted) {
    [self endUserDeclined];
  }
  [_feedbackView textViewResignFirstResponder];
  [self dismissViewControllerWithBackgroundFade];
}

- (void)sendButtonPressed:(UIButton *)sender {
  _alreadyVoted = YES;
  int score = [_npsQuestionView getScoreSliderValue];
  NSString *placeholderText = [_settings followupPlaceholderTextForScore:score];
  NSString *text = [_feedbackView feedbackText];
  [self endUserVotedWithScore:score andText:text];
  if ([_feedbackView isActive]) {
    [_feedbackView textViewResignFirstResponder];
    if ([self socialShareAvailableForScore:score]) {
      [self setupFacebookAndTwitterForScore:score];
      [self presentSocialShareViewWithScore:score];
    } else {
      [self dismissWithFinalThankYou];
    }
  } else {
    [self setQuestionViewVisible:NO andFeedbackViewVisible:YES];
    [_feedbackView setFollowupLabelTextBasedOnScore:score];
    [_feedbackView setFeedbackPlaceholderText:placeholderText];
  }
}

- (void)noThanksButtonPressed {
  [self dismissViewControllerWithBackgroundFade];
}

- (void)endUserVotedWithScore:(int)score andText:(NSString *)text {
  WTRSurvey *survey = [[WTRSurvey alloc] init];
  [survey endUserVotedWithScore:score andText:text];
  NSLog(@"WootricSDK: Vote");
}

- (void)endUserDeclined {
  WTRSurvey *survey = [[WTRSurvey alloc] init];
  [survey endUserDeclined];
  NSLog(@"WootricSDK: Decline");
}

- (void)setQuestionViewVisible:(BOOL)questionFlag andFeedbackViewVisible:(BOOL)feedbackFlag {
  _npsQuestionView.hidden = !questionFlag;
  _feedbackView.hidden = !feedbackFlag;
}

- (void)openWootricHomepage:(UIButton *)sender {
  NSURL *url = [NSURL URLWithString:@"https://www.wootric.com"];
  if (![[UIApplication sharedApplication] openURL:url]) {
    NSLog(@"Failed to open wootric page");
  }
}

- (void)facebookButtonPressed {
  NSURL *url = _settings.facebookPage;
  if (![[UIApplication sharedApplication] openURL:url]) {
    NSLog(@"Failed to open facebook page");
  }
}

- (void)twitterButtonPressed {
  if ([SLComposeViewController isAvailableForServiceType:SLServiceTypeTwitter]) {
    SLComposeViewController *tweetSheet = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeTwitter];
    [tweetSheet setInitialText:[NSString stringWithFormat:@"%@ @%@", [_feedbackView feedbackText], _settings.twitterHandler]];
    [self presentViewController:tweetSheet animated:YES completion:nil];
  } else {
    UIAlertView *alertView = [[UIAlertView alloc]
                              initWithTitle:@"Sorry"
                              message:@"You can't send a tweet right now, make sure your device has an internet connection and you have at least one Twitter account setup"
                              delegate:self
                              cancelButtonTitle:@"OK"
                              otherButtonTitles:nil];
    [alertView show];
  }
}

#pragma mark - Slider methods

- (void)sliderTapped:(UIGestureRecognizer *)gestureRecognizer {
  if (!_sendButton.enabled) {
    _sendButton.enabled = YES;
    _sendButton.backgroundColor = [WTRColor sendButtonBackgroundColor];
  }
  [_npsQuestionView sliderTapped:gestureRecognizer];
}

#pragma mark - Helper methods

- (void)setupFacebookAndTwitterForScore:(int)score {
  BOOL twitterAvailable = ([self twitterHandlerAndFeedbackTextPresent] && score >= 9);
  BOOL facebookAvailable = ([_settings facebookPageSet] && score >= 9);
  if (!twitterAvailable && !facebookAvailable) {
    _constraintModalHeight.constant = 230;
    _socialShareViewHeightConstraint.constant = 190;
    _constraintTopToModalTop.constant = self.view.frame.size.height - _constraintModalHeight.constant;
    [UIView animateWithDuration:0.2 animations:^{
      [self.view layoutIfNeeded];
    }];
  }
  [_socialShareView displayShareButtonsWithTwitterAvailable:twitterAvailable andFacebookAvailable:facebookAvailable];
}

- (BOOL)socialShareAvailableForScore:(int)score {
  return ([_settings thankYouLinkConfiguredForScore:score] ||
          ([self twitterHandlerAndFeedbackTextPresent] && score >= 9) ||
          ([_settings facebookPageSet] && score >= 9));
}

- (BOOL)twitterHandlerAndFeedbackTextPresent {
  return ([_settings twitterHandlerSet] && [_feedbackView feedbackTextPresent]);
}

- (void)presentSocialShareViewWithScore:(int)score {
  [_socialShareView setThankYouButtonTextAndURLDependingOnScore:score];
  [_socialShareView setThankYouMessageDependingOnScore:score];
  [self setQuestionViewVisible:NO andFeedbackViewVisible:NO];
  _sendButton.hidden = YES;
  _socialShareView.hidden = NO;
}

- (void)dismissWithFinalThankYou {
  _feedbackView.hidden = YES;
  _npsQuestionView.hidden = YES;
  _socialShareView.hidden = YES;
  _sendButton.hidden = YES;
  _poweredByWootric.hidden = YES;
  _finalThankYouLabel.hidden = NO;
  [_modalView hideDismissButton];
  _constraintModalHeight.constant = 125;
  _constraintTopToModalTop.constant = self.view.frame.size.height - _constraintModalHeight.constant;
  [UIView animateWithDuration:0.2 animations:^{
    [self.view layoutIfNeeded];
  }];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [self dismissViewControllerWithBackgroundFade];
  });
}

- (void)dismissViewControllerWithBackgroundFade {
  [UIView animateWithDuration:0.2 animations:^{
    self.view.backgroundColor = [UIColor clearColor];
  } completion:^(BOOL finished) {
    [self dismissViewControllerAnimated:YES completion:nil];
  }];
}

- (void)setModalGradient:(CGRect)bounds {
  _gradient.frame = bounds;
  _gradient.colors = @[(id)[WTRColor grayGradientTopColor].CGColor, (id)[WTRColor grayGradientBottomColor].CGColor];
}

- (void)getSizeAndRecalculatePositionsBasedOnOrientation:(UIInterfaceOrientation)interfaceOrientation {
  BOOL isFromLandscape = UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]);
  BOOL isToLandscape = UIInterfaceOrientationIsLandscape(interfaceOrientation);
  if ((!isFromLandscape && isToLandscape) || (isFromLandscape && !isToLandscape)) {
    CGFloat widthAfterRotation;
    CGFloat leftAndRightMargins = 28;
    if (IS_OS_8_OR_LATER || isToLandscape) {
      widthAfterRotation = self.view.frame.size.height - leftAndRightMargins;
    } else {
      widthAfterRotation = self.view.frame.size.width - leftAndRightMargins;
    }
    [_npsQuestionView recalculateDotsAndScorePositionForWidth:widthAfterRotation];
  }
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
  [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];

  CGFloat modalPosition = self.view.bounds.size.width - _modalView.frame.size.height;
  _constraintTopToModalTop.constant = modalPosition;
  [self getSizeAndRecalculatePositionsBasedOnOrientation:toInterfaceOrientation];
  BOOL isToLandscape = UIInterfaceOrientationIsLandscape(toInterfaceOrientation);
  CGRect gradientBounds;
  CGRect bounds = self.view.bounds;
  if ((bounds.size.height > bounds.size.width) && isToLandscape) {
    gradientBounds = CGRectMake(bounds.origin.y, bounds.origin.x, bounds.size.height, bounds.size.width);
  } else {
    gradientBounds = bounds;
  }
  [self setModalGradient:gradientBounds];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
  [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];

  [_scrollView scrollRectToVisible:_modalView.frame animated:YES];
}

- (void)registerForKeyboardNotification {
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:NSSelectorFromString(@"keyboardWillShow:")
                                               name:UIKeyboardWillShowNotification
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:NSSelectorFromString(@"keyboardWillHide:")
                                               name:UIKeyboardWillHideNotification
                                             object:nil];
}

- (void)keyboardWillShow:(NSNotification *)notification {
  [self adjustInsetForKeyboardShow:YES notification:notification];
}

- (void)keyboardWillHide:(NSNotification *)notification {
  [self adjustInsetForKeyboardShow:NO notification:notification];
}

- (void)adjustInsetForKeyboardShow:(BOOL)show notification:(NSNotification *)notification {
  NSDictionary *userInfo = notification.userInfo ? notification.userInfo : @{};
  CGRect keyboardFrame = [userInfo[UIKeyboardFrameBeginUserInfoKey] CGRectValue];
  double adjustmentHeight = CGRectGetHeight(keyboardFrame) * (show ? 1 : -1);
  UIEdgeInsets contentInsets = UIEdgeInsetsMake(0, 0, adjustmentHeight, 0);
  _scrollView.contentInset = contentInsets;
  _scrollView.scrollIndicatorInsets = contentInsets;

  if (!_scrolled) {
    [_scrollView scrollRectToVisible:_modalView.frame animated:YES];
    _scrolled = YES;
  }
}

- (void)textViewDidChange:(UITextView *)textView {
  if (textView.text.length == 0) {
    [_feedbackView showFeedbackPlaceholder:YES];
  } else {
    [_feedbackView showFeedbackPlaceholder:NO];
  }
}

#pragma mark - dealloc

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
