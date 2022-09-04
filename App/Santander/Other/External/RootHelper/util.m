//
//  util.m
//  Santander
//
//  Created by Nebula on 9/4/22
//  Contains code by Lars Fröder (opa334)
//

#import "util.h"

#import <Foundation/Foundation.h>
#import <spawn.h>
#import <sys/sysctl.h>

#define POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE 1
extern int posix_spawnattr_set_persona_np(const posix_spawnattr_t* __restrict, uid_t, uint32_t);
extern int posix_spawnattr_set_persona_uid_np(const posix_spawnattr_t* __restrict, uid_t);
extern int posix_spawnattr_set_persona_gid_np(const posix_spawnattr_t* __restrict, uid_t);

NSString* helperPath(void) {
    return [[NSBundle mainBundle].bundlePath stringByAppendingPathComponent:@"santanderhelper"];
}

int spawnRoot(NSString* path, NSArray* args) {
    NSMutableArray* argsM = args.mutableCopy ?: [NSMutableArray new];
    [argsM insertObject:path.lastPathComponent atIndex:0];
    
    NSUInteger argCount = [argsM count];
    char **argsC = (char **)malloc((argCount + 1) * sizeof(char*));

    for (NSUInteger i = 0; i < argCount; i++) {
        argsC[i] = strdup([[argsM objectAtIndex:i] UTF8String]);
    }
    argsC[argCount] = NULL;

    int rv;
    posix_spawnattr_t attr;
    rv = posix_spawnattr_init(&attr);
    if(rv != 0) return rv;

    posix_spawnattr_set_persona_np(&attr, 99, POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE);
    posix_spawnattr_set_persona_uid_np(&attr, 0);
    posix_spawnattr_set_persona_gid_np(&attr, 0);
    
    pid_t task_pid;
    int status = -200;
    int spawnError = posix_spawn(&task_pid, [path UTF8String], NULL, &attr, (char* const*)argsC, NULL);
    posix_spawnattr_destroy(&attr);
    for (NSUInteger i = 0; i < argCount; i++) {
        free(argsC[i]);
    }
    free(argsC);
    
    if(spawnError != 0) {
        NSLog(@"posix_spawn error %d\n", spawnError);
        return spawnError;
    }

    do {
        if (waitpid(task_pid, &status, 0) != -1) {
            NSLog(@"Child status %d", WEXITSTATUS(status));
        } else {
            perror("waitpid");
            return -222;
        }
    } while (!WIFEXITED(status) && !WIFSIGNALED(status));
    
    return WEXITSTATUS(status);
}
