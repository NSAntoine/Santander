//
//  roothelper.m
//  Santander
//
//  Created by Nebula on 9/4/22
//

#import "util.h"

#import <Foundation/Foundation.h>

int delete(NSString* path) {
    int ret;
    ret = spawnRoot(helperPath(), @[@"delete", path]);
    
    return ret;
}
