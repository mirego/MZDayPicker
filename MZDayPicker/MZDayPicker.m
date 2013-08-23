//
//  MZDayPicker.m
//  MZDayPicker
//
//  Created by Michał Zaborowski on 18.04.2013.
//  Copyright (c) 2013 whitecode. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "MZDayPicker.h"
#import "MZDayPickerCell.h"
#import <QuartzCore/QuartzCore.h>

CGFloat const kDefaultDayLabelFontSize = 25.0f;
CGFloat const kDefaultDayNameLabelFontSize = 11.0f;

CGFloat const kDefaultCellHeight = 73.0f;
CGFloat const kDefaultCellWidth = 47.0f;
CGFloat const kDefaultCellFooterHeight = 0.0f;

CGFloat const kDefaultDayLabelMaxZoomValue = 0.0f;

NSInteger const kDefaultInitialInactiveDays = 8;
NSInteger const kDefaultFinalInactiveDays = 8;

#define kDefaultColorInactiveDay [UIColor lightGrayColor]
#define kDefaultColorBackground [UIColor whiteColor]

#define kDefaultShadowColor [UIColor darkGrayColor]
#define kDefaultShadowOffset CGSizeMake(0.0, 0.0)
#define kDefaultShadowOpacity 0.35

#define kDefaultShadowCellColor [UIColor darkGrayColor]
#define kDefaultShadowCellOffset CGSizeMake(0.0, 0.0)
#define kDefaultShadowCellRadius 5

#define kDefaultColorDay [UIColor grayColor]
#define kDefaultColorDayName [UIColor darkGrayColor]
#define kDefaultColorDayNameSelected [UIColor colorWithRed:150/255.0f green:0 blue:35/255.0f alpha:1.00f]
#define kDefaultColorBottomBorder [UIColor colorWithRed:0.22f green:0.57f blue:0.80f alpha:1.00f]


static BOOL NSRangeContainsRow (NSRange range, NSInteger row) {
    
    if (row <= range.location+range.length  && row >= range.location ) {
        return YES;
    }
    
    return NO;
}

@interface MZDayPicker () <UITableViewDelegate, UITableViewDataSource>

// initialFrame property is a hack for initWithCoder:
@property (nonatomic, assign) CGRect initialFrame;

@property (nonatomic, strong) NSIndexPath* currentIndex;

@property (nonatomic, assign) CGSize dayCellSize;
@property (nonatomic, assign) CGFloat dayCellFooterHeight;

@property (nonatomic, assign) NSRange activeDays;

@property (nonatomic, strong) UITableView* tableView;

@property (nonatomic, strong) NSArray *tableDaysData;
@end


@implementation MZDayPicker
- (void)setMonth:(NSInteger)month
{
    if (_month != month) {
        _month = month;
        
        [self fillTableDataWithCurrentMonth];
        [self setupTableViewContent];
    }
}

- (void)setYear:(NSInteger)year
{
    if (_year != year) {
        _year = year;
        
        [self fillTableDataWithCurrentMonth];
        [self setupTableViewContent];
    }
}

- (void)setStartDate:(NSDate *)startDate
{
    if (self.endDate) 
        [self setStartDate:startDate endDate:self.endDate];
     else 
        [self setStartDate:startDate endDate:[startDate dateByAddingTimeInterval:3600*24]];
}

- (void)setEndDate:(NSDate *)endDate
{
    if (self.startDate)
        [self setStartDate:self.startDate endDate:endDate];
    else
        [self setStartDate:[endDate dateByAddingTimeInterval:-3600*24] endDate:endDate];
}

- (void)setDayLabelFontSize:(CGFloat)dayLabelFontSize
{
    _dayLabelFontSize = dayLabelFontSize;
    [self.tableView reloadData];
}

- (void)setDayNameLabelFontSize:(CGFloat)dayNameLabelFontSize
{
    _dayNameLabelFontSize = dayNameLabelFontSize;
    [self.tableView reloadData];
}

- (void)setDayLabelFont:(UIFont *)dayLabelFont
{
    _dayLabelFont = dayLabelFont;
    [self.tableView reloadData];
}

- (void)setDayNameLabelFont:(UIFont *)dayNameLabelFont
{
    _dayNameLabelFont = dayNameLabelFont;
    [self.tableView reloadData];
}

- (void)setDayNameLabelSelectedFont:(UIFont *)dayNameLabelSelectedFont
{
    _dayNameLabelSelectedFont = dayNameLabelSelectedFont;
    [self.tableView reloadData];
}

- (void)setActiveDaysFrom:(NSInteger)fromDay toDay:(NSInteger)toDay
{
    self.activeDays = NSMakeRange(fromDay, toDay-fromDay);
}

- (void)setActiveDays:(NSRange)activeDays
{
    _activeDays = activeDays;
    
    [self.tableView reloadData];
    
    [self setupTableViewContent];
}

- (void)setCurrentDay:(NSInteger)currentDay animated:(BOOL)animated
{
    _currentDay = currentDay;
    
    _currentIndex = [NSIndexPath indexPathForRow:currentDay+kDefaultInitialInactiveDays-1 inSection:0];

    // Hack: UITableView have bug, if i change conentInset scrolling to position not working properly
    // It is used only here, in other place i callculate contentOffset manually
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 0, 0);
    
    [self.tableView scrollToRowAtIndexPath:_currentIndex
                          atScrollPosition:UITableViewScrollPositionMiddle
                                  animated:animated];
    
    [self setupTableViewContent];

}

- (void)setCurrentDay:(NSInteger)currentDay
{
    [self setCurrentDay:currentDay animated:NO];
}

- (void)setCurrentDate:(NSDate *)date animated:(BOOL)animated
{
    if (date) {
        NSInteger components = (NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit);
        
        NSCalendar *calendar = [NSCalendar currentCalendar];
        NSDateComponents *componentsFromDate = [calendar components:components
                                                                               fromDate:date];
        
        [self.tableDaysData enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            MZDay *day = obj;
            
            NSDateComponents *componentsFromDayDate = [calendar components:components
                                                                                      fromDate: day.date];
            
            NSDate *searchingDate = [calendar dateFromComponents:componentsFromDate];
            NSDate *dayDate = [calendar dateFromComponents:componentsFromDayDate];
            
            NSComparisonResult result = [searchingDate compare:dayDate];
            
            if (result == NSOrderedSame) {
                _currentDate = date;
                [self setCurrentDay:idx-kDefaultInitialInactiveDays+1 animated:animated];
                *stop = YES;
            }
        }];
    }

}


- (void)setCurrentDate:(NSDate *)date
{
    [self setCurrentDate:date animated:NO];
}


- (void)setCurrentIndex:(NSIndexPath *)currentIndex {
    _currentIndex = currentIndex;
    
    //  In these situations you need to calculate the contentOffset manually for those cells.
    
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:currentIndex];
    
    CGFloat contentOffset = cell.center.y - (self.tableView.frame.size.width/2);
    
    [self.tableView setContentOffset:CGPointMake(self.tableView.contentOffset.x, contentOffset) animated:YES];
    
    if ([self.delegate respondsToSelector:@selector(dayPicker:didSelectDay:)])
        [self.delegate dayPicker:self didSelectDay:self.tableDaysData[currentIndex.row]];
    
    
}

- (void)setSelectedBackgroundImage:(UIImage *)selectedBackgroundImage
{
    _selectedBackgroundImage = selectedBackgroundImage;
    
    UIImageView *backgroundView = [[UIImageView alloc] initWithImage:selectedBackgroundImage];
    [backgroundView setFrame:CGRectMake((self.frame.size.width - backgroundView.frame.size.width) / 2, 0, backgroundView.frame.size.width, backgroundView.frame.size.height)];
    [self addSubview:backgroundView];
    [self sendSubviewToBack:backgroundView];
}

- (MZDayPickerCell *)cellForDay:(MZDay *)day
{
    NSInteger dayIndex = [self.tableDaysData indexOfObject:day];
    
    return (MZDayPickerCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:dayIndex inSection:0]];
}

- (void)reloadData
{
    [self.tableView reloadData];
    [self setupTableViewContent];
}

- (void)setFrame:(CGRect)frame
{
    if (CGRectIsEmpty(self.initialFrame)) self.initialFrame = frame;
    
    [super setFrame:CGRectMake(frame.origin.x, frame.origin.y, frame.size.width, frame.size.height)];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        
        _activeDayColor = kDefaultColorDay;
        _activeDayNameColor = kDefaultColorDayName;
        _inactiveDayColor = kDefaultColorInactiveDay;
        _backgroundPickerColor = kDefaultColorBackground;
        _bottomBorderColor = kDefaultColorBottomBorder;
        _dayLabelZoomScale = kDefaultDayLabelMaxZoomValue;
        _dayLabelFontSize = kDefaultDayLabelFontSize;
        _dayNameLabelFontSize = kDefaultDayNameLabelFontSize;
        
        [self setActiveDaysFrom:1 toDay:[NSDate dateFromDay:1 month:self.month year:self.year].numberOfDaysInMonth-1];
        
        // Make the UITableView's height the width, and width the height so that when we rotate it it will fit exactly
        self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, frame.size.height, frame.size.width)];
        self.tableView.delegate = self;
        self.tableView.dataSource = self;
        self.tableView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin);
        
        // Rotate the tableview by 90 degrees so that it is side scrollable
        self.tableView.transform = CGAffineTransformMakeRotation(-M_PI_2);
        self.tableView.center = self.center;
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.tableView.backgroundColor = [UIColor clearColor];
        self.tableView.showsVerticalScrollIndicator = NO;
        self.tableView.decelerationRate = UIScrollViewDecelerationRateFast;
        self.tableView.scrollsToTop = NO;
        
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGestureRecognizer:)];
        [self.tableView addGestureRecognizer:tapGesture];
        
        [self addSubview: self.tableView];
        
        self.backgroundColor = kDefaultColorBackground;
        
        self.layer.frame = CGRectMake(0, 0, self.layer.frame.size.width, self.layer.frame.size.height-self.dayCellFooterHeight);
        self.layer.shadowColor = kDefaultShadowColor.CGColor;
        self.layer.shadowOffset = kDefaultShadowOffset;
        self.layer.shadowOpacity = kDefaultShadowOpacity;
        self.layer.shadowRadius = 5;
        self.layer.shadowPath = [UIBezierPath bezierPathWithRect:self.bounds].CGPath;
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [self setupTableViewContent];

    [self setCurrentDate:self.currentDate animated:NO];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {

        self =  [self initWithFrame:CGRectMake(0, 0, self.initialFrame.size.width, self.initialFrame.size.height) dayCellSize:CGSizeMake(self.initialFrame.size.height-kDefaultCellFooterHeight, self.initialFrame.size.height-kDefaultCellFooterHeight) dayCellFooterHeight:kDefaultCellFooterHeight month:1 year:1970];

        if ([[UIDevice currentDevice].systemVersion floatValue] >= 6.0) {
            self.frame = CGRectMake(self.initialFrame.origin.x, 0, self.frame.size.width, self.initialFrame.origin.y+self.frame.size.height+self.dayCellFooterHeight);
        } else {
            self.frame = CGRectMake(self.initialFrame.origin.x, self.initialFrame.origin.y, self.frame.size.width, self.initialFrame.size.height+self.dayCellFooterHeight);
        }
        
    }

    return self;
}

- (instancetype)initWithFrame:(CGRect)frame dayCellSize:(CGSize)cellSize dayCellFooterHeight:(CGFloat)footerHeight
{
    if (self = [self initWithFrame:frame dayCellSize:CGSizeMake(kDefaultCellWidth, kDefaultCellHeight) dayCellFooterHeight:kDefaultCellFooterHeight month:1 year:1970]) {
        
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame month:(NSInteger)month year:(NSInteger)year
{
    if (self = [self initWithFrame:frame dayCellSize:CGSizeMake(kDefaultCellWidth, kDefaultCellHeight) dayCellFooterHeight:kDefaultCellFooterHeight month:month year:year]) {
        
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame dayCellSize:(CGSize)cellSize dayCellFooterHeight:(CGFloat)footerHeight month:(NSInteger)month year:(NSInteger)year
{
    _dayCellSize = cellSize;
    _dayCellFooterHeight = footerHeight;
    
    if (self = [self initWithFrame:frame])
    {
        _month = month;
        _year = year;
        
        [self fillTableDataWithCurrentMonth];
        
        self.currentDay = 14;
    }
    
    return self;
}

- (void)setupTableViewContent
{
    // *|1|2|3|4|5
    CGFloat startActiveDaysWidth = (kDefaultInitialInactiveDays*self.dayCellSize.width) + ((self.activeDays.location-1)*self.dayCellSize.width);
    
    // *|-|-|1|2|3|
    CGFloat insetLimit = startActiveDaysWidth - (self.frame.size.width/2) + (self.dayCellSize.width/2);
    
    self.tableView.contentInset = UIEdgeInsetsMake(-insetLimit, 0, 0, 0);
    
    CGFloat contentSizeLimit = startActiveDaysWidth + ((self.activeDays.length+1)*self.dayCellSize.width) + (self.frame.size.width/2) - (self.dayCellSize.width/2);
    
    self.tableView.contentSize = CGSizeMake(self.tableView.frame.size.height, contentSizeLimit);
    
}

- (void)setStartDate:(NSDate *)startDate endDate:(NSDate *)endDate
{
    _startDate = [NSDate dateWithNoTime:startDate middleDay:YES];
    _endDate = [NSDate dateWithNoTime:endDate middleDay:YES];

    NSMutableArray *tableData = [NSMutableArray array];
    
    NSDateFormatter *dateNameFormatter = [[NSDateFormatter alloc] init];
    [dateNameFormatter setDateFormat:@"EEEE"];
    
    NSDateFormatter *dateNumberFormatter = [[NSDateFormatter alloc] init];
    [dateNumberFormatter setDateFormat:@"dd"];
    
    for (int i = kDefaultInitialInactiveDays; i >= 1; i--) {
        NSDate *date = [_startDate dateByAddingTimeInterval:-(i * 60.0 * 60.0 * 24.0)];
        NSDateComponents *components = [[NSCalendar currentCalendar] components:NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit fromDate:date];

        MZDay *newDay = [[MZDay alloc] init];
        newDay.day = [NSNumber numberWithInt:components.day];
        newDay.month = [NSNumber numberWithInt:components.month];
        newDay.year = [NSNumber numberWithInt:components.year];
        newDay.name = [dateNameFormatter stringFromDate:date];
        newDay.date = date;
        
        [tableData addObject:newDay];
    }
    
    NSInteger numberOfActiveDays = 0;
    
    for (NSDate *date = _startDate; [date compare: _endDate] <= 0; date = [date dateByAddingTimeInterval:24 * 60 * 60] ) {
        NSDateComponents *components = [[NSCalendar currentCalendar] components:NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit fromDate:date];
        
        MZDay *newDay = [[MZDay alloc] init];
        newDay.day = [NSNumber numberWithInt:components.day];
        newDay.month = [NSNumber numberWithInt:components.month];
        newDay.year = [NSNumber numberWithInt:components.year];
        newDay.name = [dateNameFormatter stringFromDate:date];
        newDay.date = date;
        
        [tableData addObject:newDay];
        
        numberOfActiveDays++;
    }
    
    for (int i = 1; i <= kDefaultFinalInactiveDays; i++) {
        NSDate *date = [_endDate dateByAddingTimeInterval:(i * 60.0 * 60.0 * 24.0)];

        NSDateComponents *components = [[NSCalendar currentCalendar] components:NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit fromDate:date];
        
        MZDay *newDay = [[MZDay alloc] init];
        newDay.day = [NSNumber numberWithInt:components.day];
        newDay.month = [NSNumber numberWithInt:components.month];
        newDay.year = [NSNumber numberWithInt:components.year];
        newDay.name = [dateNameFormatter stringFromDate:date];
        newDay.date = date;
        
        [tableData addObject:newDay];
    }
    
    self.tableDaysData = [tableData copy];
    
    [self setActiveDaysFrom:1 toDay:numberOfActiveDays];
    
    [self.tableView reloadData];
}

- (void)fillTableDataWithCurrentMonth
{
    NSDate *startDate = [NSDate dateFromDay:1 month:self.month year:self.year];
    NSDate *endDate = [NSDate dateFromDay:startDate.numberOfDaysInMonth-1 month:self.month year:self.year];
    
    [self setStartDate:startDate endDate:endDate];
}

#pragma mark - UITapGestureRecognizer

- (void)handleTapGestureRecognizer:(UITapGestureRecognizer *)tapGesture
{
    if (tapGesture.state == UIGestureRecognizerStateEnded) {
        
        CGPoint location = [tapGesture locationInView:tapGesture.view];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
        
        if (NSRangeContainsRow(self.activeDays, indexPath.row - kDefaultInitialInactiveDays + 1))
        {
            if (indexPath.row != self.currentIndex.row) {
                
                if ([self.delegate respondsToSelector:@selector(dayPicker:willSelectDay:)])
                    [self.delegate dayPicker:self willSelectDay:self.tableDaysData[indexPath.row-1]];
                
                _currentDay = indexPath.row-1;
                _currentDate = [(MZDay *)self.tableDaysData[indexPath.row] date];
                [self setCurrentIndex:indexPath];
            }
        }
    }
}

#pragma mark - UIScrollView delegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    
    if ([self.delegate respondsToSelector:@selector(dayPicker:scrollViewDidScroll:)]) {
        [self.delegate dayPicker:self scrollViewDidScroll:scrollView];
    }
    
    CGPoint centerTableViewPoint = [self convertPoint:CGPointMake(self.frame.size.width/2.0, self.dayCellSize.height/2.0) toView:self.tableView];
    
    // Zooming visible cell's
    for (MZDayPickerCell *cell in self.tableView.visibleCells) {
        
        @autoreleasepool {
            // Distance between cell center point and center of tableView
            CGFloat distance = cell.center.y - centerTableViewPoint.y;
            
            // Zoom step using cosinus
            CGFloat zoomStep = cosf(M_PI_2*distance/self.dayCellSize.width);
            
            if (distance < self.dayCellSize.width / 2 && distance > -self.dayCellSize.width / 2) {
                
                if (_dayLabelFont) {
                    cell.dayLabel.font = _dayLabelFont;
                    [cell.dayLabel setTextColor:[UIColor whiteColor]];
                } else {
                    cell.dayLabel.font = [cell.dayLabel.font fontWithSize:self.dayLabelFontSize + self.dayLabelZoomScale * zoomStep];
                }
                
                if (_dayNameLabelFont) {
                    cell.dayNameLabel.font = _dayNameLabelSelectedFont;
                }
                cell.dayNameLabel.textColor = kDefaultColorDayNameSelected;

                [cell setBottomBorderSlideHeight:zoomStep];
                
                //NSIndexPath* centerIndexPath = [self.tableView indexPathForRowAtPoint:CGPointMake(0, point.y)];
                //NSDate* newDate = [(MZDay *)self.tableDaysData[centerIndexPath.row] date];
                NSIndexPath *currentIndexPath = [_tableView indexPathForCell:cell];
                MZDay *day = self.tableDaysData[currentIndexPath.row - 1];
                if ([self.delegate respondsToSelector:@selector(dayPicker:willOverDay:)]) {
                    [self.delegate dayPicker:self willOverDay:day];
                }
                
            } else {
                if (_dayLabelFont) {
                    cell.dayLabel.font = _dayLabelFont;
                    [cell.dayLabel setTextColor:kDefaultColorDay];
                } else {
                    cell.dayLabel.font = [cell.dayLabel.font fontWithSize:self.dayLabelFontSize];
                }
                cell.dayNameLabel.textColor = kDefaultColorDayName;

                if (_dayNameLabelFont) {
                    cell.dayNameLabel.font = _dayNameLabelFont;
                }
                [cell setBottomBorderSlideHeight:0.0];
            }
            
            CGFloat shadowStep = cosf(M_PI_2*distance/self.dayCellSize.width*2);
            
            if (distance < self.dayCellSize.width/2 && distance > -self.dayCellSize.width/2) {
                cell.containerView.backgroundColor = self.backgroundPickerColor;
            } else {
                cell.containerView.backgroundColor = [UIColor clearColor];
            }
            
        }
    }
    
    if (_currentDate) {
        CGPoint point = [self convertPoint:CGPointMake(self.frame.size.width/2.0, self.dayCellSize.height/2.0) toView:self.tableView];
        
        NSIndexPath* centerIndexPath = [self.tableView indexPathForRowAtPoint:CGPointMake(0, point.y)];
        NSDate* newDate = [(MZDay *)self.tableDaysData[centerIndexPath.row] date];
        MZDay *day = self.tableDaysData[centerIndexPath.row];
        
        NSDateComponents *newComponents = [[NSCalendar currentCalendar] components:NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit fromDate:newDate];
        NSDateComponents *oldComponents = [[NSCalendar currentCalendar] components:NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit fromDate:_currentDate];

        if (oldComponents.month != newComponents.month) {
            if ([self.delegate respondsToSelector:@selector(dayPicker:monthDidChange:)]) {
                [self.delegate dayPicker:self monthDidChange:day];
            }
        }
        
        if (oldComponents.year != newComponents.year) {
            if ([self.delegate respondsToSelector:@selector(dayPicker:yearDidChange:)]) {
                [self.delegate dayPicker:self yearDidChange:day];
            }
        }
        
        _currentDate = newDate;
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if ([self.delegate respondsToSelector:@selector(dayPicker:scrollViewDidEndDecelerating:)]) {
        [self.delegate dayPicker:self scrollViewDidEndDecelerating:scrollView];
    }
    
    
    [self scrollViewDidFinishScrolling:scrollView];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if ([self.delegate respondsToSelector:@selector(dayPicker:scrollViewWillBeginDragging:)]) {
        [self.delegate dayPicker:self scrollViewWillBeginDragging:scrollView];
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if ([self.delegate respondsToSelector:@selector(dayPicker:scrollViewDidEndDragging:)]) {
        [self.delegate dayPicker:self scrollViewDidEndDragging:scrollView];
    }
    
    if(!decelerate) {
        [self scrollViewDidFinishScrolling:scrollView];
    }
    
}

- (void)scrollViewDidFinishScrolling:(UIScrollView*)scrollView {
    CGPoint point = [self convertPoint:CGPointMake(self.frame.size.width/2.0, self.dayCellSize.height/2.0) toView:self.tableView];
    
    NSIndexPath* centerIndexPath = [self.tableView indexPathForRowAtPoint:CGPointMake(0, point.y)];
    
    if (centerIndexPath.row != self.currentIndex.row) {
        if ([self.delegate respondsToSelector:@selector(dayPicker:willSelectDay:)])
            [self.delegate dayPicker:self willSelectDay:self.tableDaysData[centerIndexPath.row - 1]];
        
        _currentDay = centerIndexPath.row-1;
        _currentDate = [(MZDay *)self.tableDaysData[centerIndexPath.row] date];
        self.currentIndex = centerIndexPath;
        
    } else {
        // Go back to currentIndex
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:_currentIndex];
        
        CGFloat contentOffset = cell.center.y - (self.tableView.frame.size.width/2);
        
        [self.tableView setContentOffset:CGPointMake(self.tableView.contentOffset.x, contentOffset) animated:YES];
    }

    
}

#pragma mark - UITableView dataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.tableDaysData.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return self.dayCellSize.width;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString* reuseIdentifier = @"MZDayPickerCell";
    
    MZDayPickerCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    
    if (!cell) {
        cell = [[MZDayPickerCell alloc] initWithSize:self.dayCellSize footerHeight:self.dayCellFooterHeight reuseIdentifier:reuseIdentifier];
    }
    
    MZDay *day = self.tableDaysData[indexPath.row];

    MZDay *dayForEvent = self.tableDaysData[indexPath.row - 1];
    [cell setNumberOfEvents:[self numberOfEventsForDate:dayForEvent.date]];
    
    if ([dayForEvent.date compare:[NSDate date]] == NSOrderedDescending) {
        [cell.eventsLabel setTextColor:_futureEventsColor];
    } else {
        [cell.eventsLabel setTextColor:_pastEventsColor];
    }

    // Bug: I can't use default UITableView select row, because in some case, row's didn't selected
    // I Handled it by tap gesture recognizer
    [cell setUserInteractionEnabled:NO];
    
    cell.dayLabel.textColor = self.activeDayNameColor;
    
    if (_dayNameLabelFont) {
        cell.dayNameLabel.font = _dayNameLabelFont;
    } else {
        cell.dayNameLabel.font = [cell.dayLabel.font fontWithSize:self.dayNameLabelFontSize];
    }
    cell.dayNameLabel.textColor = self.activeDayNameColor;
    [cell setBottomBorderColor:self.bottomBorderColor];
    
    cell.dayLabel.text = [NSString stringWithFormat:@"%@",day.day];
    
    cell.dayNameLabel.text = [NSString stringWithFormat:@"%@",[day.name substringToIndex:3]];
    
    if ([self.dataSource respondsToSelector:@selector(dayPicker:titleForCellDayLabelInDay:)]) {
        cell.dayLabel.text = [self.dataSource dayPicker:self titleForCellDayLabelInDay:day];
    }
    
    if ([self.dataSource respondsToSelector:@selector(dayPicker:titleForCellDayNameLabelInDay:)]) {
        cell.dayNameLabel.text = [self.dataSource dayPicker:self titleForCellDayNameLabelInDay:day];
    }
    
    [self setShadowForCell:cell];
    
    if (NSRangeContainsRow(self.activeDays, indexPath.row - kDefaultInitialInactiveDays + 1)) {
        cell.dayLabel.textColor = kDefaultColorDay;
        cell.dayNameLabel.textColor = kDefaultColorDayName;
        
    } else {
        cell.dayLabel.textColor = kDefaultColorInactiveDay;
        cell.dayNameLabel.textColor = kDefaultColorInactiveDay;
    }
    
    if (indexPath.row == _currentIndex.row) {
        cell.containerView.backgroundColor = self.backgroundPickerColor;
        cell.containerView.layer.shadowOpacity = 0;
        
        [cell setBottomBorderSlideHeight:1.0];
        
        if (_dayLabelFont) {
            [cell.dayLabel setFont:_dayLabelFont];
        } else {
            cell.dayLabel.font = [cell.dayLabel.font fontWithSize:self.dayLabelFontSize+self.dayLabelZoomScale];
        }
        
        if (_dayNameLabelSelectedFont) {
            cell.dayNameLabel.font = _dayNameLabelSelectedFont;
        }
        
        cell.dayNameLabel.textColor = kDefaultColorDayNameSelected;
        [cell.dayLabel setTextColor:[UIColor whiteColor]];
        
    } else {
        if (_dayLabelFont) {
            cell.dayLabel.font = _dayLabelFont;
            [cell.dayLabel setTextColor:kDefaultColorDay];
        } else {
            cell.dayLabel.font = [cell.dayLabel.font fontWithSize:self.dayLabelFontSize];
        }
        
        if (_dayNameLabelFont) {
            cell.dayNameLabel.font = _dayNameLabelFont;
        }
        
        cell.dayNameLabel.textColor = kDefaultColorDayName;
        cell.containerView.backgroundColor = [UIColor clearColor];
        [cell setBottomBorderSlideHeight:0];
    }
    
    [cell setBackgroundColor:[UIColor clearColor]];
    
    return cell;
    
}

- (void)setShadowForCell:(MZDayPickerCell *)cell
{
    cell.containerView.layer.masksToBounds = NO;
    cell.containerView.layer.shadowOffset = kDefaultShadowCellOffset;
    cell.containerView.layer.shadowRadius = kDefaultShadowCellRadius;
    cell.containerView.layer.shadowOpacity = 0.0;
    cell.containerView.layer.shadowColor = kDefaultShadowCellColor.CGColor;
    cell.containerView.layer.shadowPath = [UIBezierPath bezierPathWithRect:cell.containerView.bounds].CGPath;
}

- (void)setEventDates:(NSArray *)eventDates
{
    _eventDates = eventDates;
    [self.tableView reloadData];
}

- (NSInteger)numberOfEventsForDate:(NSDate *)date
{
    NSInteger numberOfEvents = 0;
    for (NSDate *eventDate in _eventDates) {
        if ([eventDate compare:date] == NSOrderedSame) {
            numberOfEvents++;
        }
    }

    return numberOfEvents;
}

@end

#pragma mark - NSDate (Additional) implementation

@implementation NSDate (Additional)

+ (NSDate *)dateFromDay:(NSInteger)day month:(NSInteger)month year:(NSInteger)year
{
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [[NSDateComponents alloc] init];
    [calendar setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
    
    [components setDay:day];
    
    if (month <= 0) {
        [components setMonth:12-month];
        [components setYear:year-1];
    } else if (month >= 13) {
        [components setMonth:month-12];
        [components setYear:year+1];
    } else {
        [components setMonth:month];
        [components setYear:year];
    }
    
    
    return [NSDate dateWithNoTime:[calendar dateFromComponents:components] middleDay:NO];
}

+ (NSDate *)dateWithNoTime:(NSDate *)dateTime middleDay:(BOOL)middle
{
    if( dateTime == nil ) {
        dateTime = [NSDate date];
    }
    
    NSCalendar       *calendar   = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    [calendar setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
    NSDateComponents *components = [[NSDateComponents alloc] init];
    components = [calendar components:NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit
                             fromDate:dateTime];
    
    NSDate *dateOnly = [calendar dateFromComponents:components];
    
    if (middle)
       [dateOnly dateByAddingTimeInterval:(60.0 * 60.0 * 12.0)];           // Push to Middle of day. 

    return dateOnly;
}

- (NSUInteger)numberOfDaysInMonth
{
    NSCalendar *c = [NSCalendar currentCalendar];
    NSRange days = [c rangeOfUnit:NSDayCalendarUnit
                           inUnit:NSMonthCalendarUnit
                          forDate:self];
    
    return days.length;
}

@end
