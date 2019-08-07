//
//  ActionQueue.m
//  Block Buster
//
//  Created by Joao Santos on 07/08/2019.
//  Copyright © 2019 Joao Santos. All rights reserved.
//

#import "ActionQueue.h"

static ActionQueue *actionQueue;
static NSTimer __weak *actionTimer;

@implementation ActionQueue {
    ActionQueue *_next, __weak *_prev;
    void (^_action)(void);
}

+ (void)enqueueAction:(void (^)(void))action
{
    ActionQueue *current = [ActionQueue new];
    current->_action = action;
    if (actionQueue) {
        current->_next = actionQueue;
        current->_prev = actionQueue->_prev;
        current->_prev->_next = current;
        current->_next->_prev = current;
    } else {
        actionQueue = current;
        current->_next = current;
        current->_prev = current;
        void (^dequeue)(NSTimer *) = ^(NSTimer *timer) {
            ActionQueue *current = actionQueue;
            actionQueue = current->_next;
            current->_next->_prev = current->_prev;
            current->_prev->_next = current->_next;
            current->_action();
            if (actionQueue == current) {
                actionQueue = nil;
                [actionTimer invalidate];
            }
        };
        actionTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:dequeue];
    }
}

@end
