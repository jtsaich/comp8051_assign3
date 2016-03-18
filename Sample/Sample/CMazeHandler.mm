//
//  Maze.m
//  Assignment 2
//
//  Created by Jack Tsai on 2016-02-24.
//  Copyright © 2016 Jack Tsai. All rights reserved.
//

#import "CMazeHandler.h"
#include "maze.h"

struct MazeClass {
    Maze maze;
};

@implementation CMazeHandler {
    struct MazeClass *maze;
}


- (id)init:(int)rows cols:(int)cols {
    if (self = [super init]) {
        maze = new MazeClass;
        maze->maze.Create();
    }
    return self;
}

- (int)rows {
    return maze->maze.rows;
}

- (int)cols {
    return maze->maze.cols;
}

- (struct MazeCell)GetCell:(int)row col:(int)col {
    return maze->maze.GetCell(row, col);
}

- (bool)northWallPresent:(int)row col:(int)col {
    return maze->maze.GetCell(row, col).northWallPresent;
}

- (bool)westWallPresent:(int)row col:(int)col {
    return maze->maze.GetCell(row, col).westWallPresent;
}

- (bool)southWallPresent:(int)row col:(int)col {
    return maze->maze.GetCell(row, col).southWallPresent;
}

- (bool)eastWallPresent:(int)row col:(int)col {
    return maze->maze.GetCell(row, col).eastWallPresent;
}

@end
