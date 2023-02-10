//
//  main.swift
//  RootHelper
//
//  Created by Serena on 17/10/2022
//

import ArgumentParser
import Foundation
import NSTask // proc_pidpath

// get the parent caller, and make sure it's Santander, otherwise, gtfo
var buffer = [CChar](repeating: 0, count: 1024)
proc_pidpath(getppid(), &buffer, 1024)

let path = URL(fileURLWithPath: String(cString: buffer))

// We don't verify the whole path as /Applications/Santander.app/Santander, if we did that
// then this root helper would have to be modified on forks like the TrollStore one,
// where the .app name & path are different
// instead, we make sure that the binary name (which should ALWAYS be 'Santander') is correct.
guard path.lastPathComponent == "Santander" else {
    fatalError("Incorrect parent calling, goodbye!")
}

//NSLog("FileHandle.standardInput.availableData.count: \(FileHandle.standardInput.availableData.count)")

setuid(0)
setgid(0)

guard getuid() == 0 else {
    fputs("getuid() returned a uid that wasn't 0, in other words, we werent able to get root.", stderr)
    exit(-1)
}

struct Program: ParsableCommand {
    static let configuration: CommandConfiguration = CommandConfiguration(
        subcommands: [
            Create.self,
            Delete.self,
            
            Move.self,
            Copy.self,
            Link.self,
            Rename.self,
            
            SetOwnerOrGroup.self,
            SetPermissions.self,
            
            Compress.self,
            Decompress.self,
            
            WriteData.self,
            WriteString.self,
            
            GetContents.self
        ]
    )
}

do {
    var command = try Program.parseAsRoot(nil)
    try command.run()
} catch {
    fputs(error.localizedDescription, stderr)
    exit(-1)
}
