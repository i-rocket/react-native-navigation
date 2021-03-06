#import "RNNModalManager.h"
#import "RNNComponentViewController.h"
#import "RNNAnimationsTransitionDelegate.h"
#import "UIViewController+LayoutProtocol.h"

@implementation RNNModalManager {
	NSMutableArray* _pendingModalIdsToDismiss;
	NSMutableArray* _presentedModals;
}


-(instancetype)init {
	self = [super init];
	_pendingModalIdsToDismiss = [[NSMutableArray alloc] init];
	_presentedModals = [[NSMutableArray alloc] init];

	return self;
}

-(void)showModal:(UIViewController *)viewController animated:(BOOL)animated completion:(RNNTransitionWithComponentIdCompletionBlock)completion {
	[self showModal:viewController animated:animated hasCustomAnimation:NO completion:completion];
}

-(void)showModal:(UIViewController<RNNLayoutProtocol> *)viewController animated:(BOOL)animated hasCustomAnimation:(BOOL)hasCustomAnimation completion:(RNNTransitionWithComponentIdCompletionBlock)completion {
	if (!viewController) {
		@throw [NSException exceptionWithName:@"ShowUnknownModal" reason:@"showModal called with nil viewController" userInfo:nil];
	}
	
	UIViewController* topVC = [self topPresentedVC];
	topVC.definesPresentationContext = YES;
	
	if (viewController.presentationController) {
		viewController.presentationController.delegate = self;
	}
	
	RNNAnimationsTransitionDelegate* tr = [[RNNAnimationsTransitionDelegate alloc] initWithScreenTransition:viewController.resolveOptions.animations.showModal isDismiss:NO];
	if (hasCustomAnimation) {
		viewController.transitioningDelegate = tr;
	}
	
	[topVC presentViewController:viewController animated:animated completion:^{
		if (completion) {
			completion(nil);
		}
		
        [self->_presentedModals addObject:[viewController topMostViewController]];
	}];
}

- (void)dismissModal:(UIViewController *)viewController completion:(RNNTransitionCompletionBlock)completion {
	if (viewController) {
		[_pendingModalIdsToDismiss addObject:viewController];
		[self removePendingNextModalIfOnTop:completion];
	}
}

- (void)dismissAllModalsAnimated:(BOOL)animated completion:(void (^ __nullable)(void))completion {
	UIViewController *root = UIApplication.sharedApplication.delegate.window.rootViewController;
	[root dismissViewControllerAnimated:animated completion:completion];
	[_delegate dismissedMultipleModals:_presentedModals];
	[_pendingModalIdsToDismiss removeAllObjects];
	[_presentedModals removeAllObjects];
}

- (void)dismissAllModalsSynchronosly {
	if (_presentedModals.count) {
		dispatch_semaphore_t sem = dispatch_semaphore_create(0);
		[self dismissAllModalsAnimated:NO completion:^{
			dispatch_semaphore_signal(sem);
		}];
		
		while (dispatch_semaphore_wait(sem, DISPATCH_TIME_NOW)) {
			[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0]];
		}
	}
}

#pragma mark - private


-(void)removePendingNextModalIfOnTop:(RNNTransitionCompletionBlock)completion {
	UIViewController<RNNLayoutProtocol> *modalToDismiss = [_pendingModalIdsToDismiss lastObject];
	RNNNavigationOptions* options = modalToDismiss.resolveOptions;

	if(!modalToDismiss) {
		return;
	}

	UIViewController* topPresentedVC = [self topPresentedVC];
	RNNAnimationsTransitionDelegate* tr = [[RNNAnimationsTransitionDelegate alloc] initWithScreenTransition:modalToDismiss.resolveOptions.animations.dismissModal isDismiss:YES];
	if ([options.animations.dismissModal hasCustomAnimation]) {
		[self topViewControllerParent:modalToDismiss].transitioningDelegate = tr;
	}

	if (modalToDismiss == topPresentedVC || [[topPresentedVC childViewControllers] containsObject:modalToDismiss]) {
		[modalToDismiss dismissViewControllerAnimated:[options.animations.dismissModal.enable getWithDefaultValue:YES] completion:^{
			[_pendingModalIdsToDismiss removeObject:modalToDismiss];
			if (modalToDismiss.view) {
				[self dismissedModal:modalToDismiss];
			}
			
			if (completion) {
				completion();
			}
			
			[self removePendingNextModalIfOnTop:nil];
		}];
	} else {
		[modalToDismiss.view removeFromSuperview];
		modalToDismiss.view = nil;
		modalToDismiss.getCurrentChild.resolveOptions.animations.dismissModal.enable = [[Bool alloc] initWithBOOL:NO];
		[self dismissedModal:modalToDismiss];
		
		if (completion) {
			completion();
		}
	}
}

- (void)dismissedModal:(UIViewController *)viewController {
	[_presentedModals removeObject:[viewController topMostViewController]];
	[_delegate dismissedModal:viewController.presentedComponentViewController];
}

- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController {
	[_presentedModals removeObject:presentationController.presentedViewController];
    [_delegate dismissedModal:presentationController.presentedViewController.presentedComponentViewController];
}

-(UIViewController*)topPresentedVC {
	UIViewController *root = UIApplication.sharedApplication.delegate.window.rootViewController;
	while(root.presentedViewController) {
		root = root.presentedViewController;
	}
	return root;
}

-(UIViewController*)topPresentedVCLeaf {
	id root = [self topPresentedVC];
	return [root topViewController] ? [root topViewController] : root;
}

- (UIViewController *)topViewControllerParent:(UIViewController *)viewController {
	UIViewController* topParent = viewController;
	while (topParent.parentViewController) {
		topParent = topParent.parentViewController;
	}
	
	return topParent;
}


@end
