//
//  UVInstantAnswerManager.m
//  UserVoice
//
//  Created by Austin Taylor on 10/17/13.
//  Copyright (c) 2013 UserVoice Inc. All rights reserved.
//

#import "UVInstantAnswerManager.h"
#import "UVArticle.h"
#import "UVSuggestion.h"
#import "UVDeflection.h"
#import "UVBabayaga.h"
#import "UVArticleViewController.h"
#import "UVSuggestionDetailsViewController.h"
#import "UVInstantAnswersViewController.h"

@implementation UVInstantAnswerManager

- (void)setSearchText:(NSString *)newText {
    if ([_searchText.lowercaseString isEqualToString:newText.lowercaseString]) {
        return;
    }
    _searchText = newText;
    [self invalidateTimer];
    if (_searchText == nil || _searchText.length == 0) {
        self.instantAnswers = self.ideas = self.articles = [NSArray array];
        [_delegate didUpdateInstantAnswers];
    } else {
        self.timer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(doSearch:) userInfo:nil repeats:NO];
    }
}

- (void)search {
    [_timer fire];
    [self invalidateTimer];
}

- (void)invalidateTimer {
    [_timer invalidate];
    self.timer = nil;
}

- (void)doSearch:(NSTimer *)timer {
    _loading = YES;
    self.runningQuery = _searchText;
    [UVDeflection setSearchText:_searchText];
    [UVArticle getInstantAnswers:_searchText delegate:self];
}

- (void)didRetrieveInstantAnswers:(NSArray *)theInstantAnswers {
    self.instantAnswers = theInstantAnswers;
    self.ideas = [theInstantAnswers filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"class == %@", [UVSuggestion class]]];
    self.articles = [theInstantAnswers filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"class == %@", [UVArticle class]]];
    _loading = NO;
    [_delegate didUpdateInstantAnswers];
    
    NSMutableArray *articleIds = [NSMutableArray arrayWithCapacity:_articles.count];
    for (id answer in _articles) {
        [articleIds addObject:@(((UVArticle *)answer).articleId)];
    }
    [UVBabayaga track:SEARCH_ARTICLES searchText:_runningQuery ids:articleIds];
    
    NSMutableArray *ideaIds = [NSMutableArray arrayWithCapacity:_ideas.count];
    for (id answer in _ideas) {
        [ideaIds addObject:@(((UVSuggestion *)answer).suggestionId)];
    }
    [UVBabayaga track:SEARCH_IDEAS searchText:_runningQuery ids:ideaIds];
    // note: UVDeflection should be called later with the actual objects displayed to the user
}

- (void)skipInstantAnswers {
    if ([_delegate respondsToSelector:@selector(skipInstantAnswers)])
        [_delegate skipInstantAnswers];
}

- (void)pushInstantAnswersViewForParent:(UIViewController *)parent articlesFirst:(BOOL)articlesFirst {
    if (_instantAnswers.count > 0) {
        UVInstantAnswersViewController *next = [UVInstantAnswersViewController new];
        next.instantAnswerManager = self;
        next.articlesFirst = articlesFirst;
        [parent.navigationController pushViewController:next animated:YES];
    } else {
        [self skipInstantAnswers];
    }
}

- (void)pushViewFor:(id)instantAnswer parent:(UIViewController *)parent {
    [UVDeflection trackDeflection:@"show" deflector:instantAnswer];
    if ([instantAnswer isMemberOfClass:[UVArticle class]]) {
        UVArticleViewController *next = [UVArticleViewController new];
        next.article = (UVArticle *)instantAnswer;
        next.helpfulPrompt = _articleHelpfulPrompt;
        next.returnMessage = _articleReturnMessage;
        next.instantAnswers = YES;
        [parent.navigationController pushViewController:next animated:YES];
    } else {
        UVSuggestion *suggestion = (UVSuggestion *)instantAnswer;
        UVSuggestionDetailsViewController *next = [[UVSuggestionDetailsViewController alloc] initWithSuggestion:suggestion];
        next.helpfulPrompt = _articleHelpfulPrompt;
        next.returnMessage = _articleReturnMessage;
        next.instantAnswers = YES;
        [parent.navigationController pushViewController:next animated:YES];
    }
}

- (void)didReceiveError:(NSError *)error {
    if ([_delegate respondsToSelector:@selector(didReceiveError:)]) {
        [_delegate didReceiveError:error];
    }
}

- (void)dealloc {
    [self invalidateTimer];
}

@end