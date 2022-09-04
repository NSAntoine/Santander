@import Foundation;

BOOL delete(NSString* path) {
    return [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

int main(int argc, char *argv[], char *envp[]) {
	@autoreleasepool {
		if(argc <= 1) return -1;

		NSLog(@"[SantanderHelper] spawned, uid: %d, gid: %d", getuid(), getgid());

		int ret = 0;

        NSString* cmd = [NSString stringWithUTF8String:argv[1]];
		if([cmd isEqualToString:@"delete"]) {
            if(argc <= 2) return -3;
			NSString* path = [NSString stringWithUTF8String:argv[2]];
            NSLog(@"[SantanderHelper] called delete: %d", path)
            
            delete(path);
        }

        NSLog(@"[SantanderHelper] returning %d", ret);
		return ret;
    }
}