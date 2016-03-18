//
//  Maze.h
//  Assignment 2
//
//  Created by Jack Tsai on 2016-02-24.
//  Copyright © 2016 Jack Tsai. All rights reserved.
//

#import <Foundation/Foundation.h>

struct MazeClass;

@interface CMazeHandler : NSObject

- (id)init:(int)rows cols:(int)cols;
- (int)rows;
- (int)cols;
- (struct MazeCell)GetCell:(int)row col:(int)col;
- (bool)northWallPresent:(int)row col:(int)col;
- (bool)westWallPresent:(int)row col:(int)col;
- (bool)southWallPresent:(int)row col:(int)col;
- (bool)eastWallPresent:(int)row col:(int)col;

@end
