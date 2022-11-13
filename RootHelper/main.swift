//
//  main.swift
//  RootHelper
//
//  Created by Serena on 17/10/2022
//

import Foundation
import FSOperations
import ArgumentParser
import NSTaskBridge

// get the parent caller, and make sure it's Santander, otherwise, gtfo
var buffer = [CChar](repeating: 0, count: 1024)
proc_pidpath(getppid(), &buffer, 1024)

let path = String(cString: buffer)

guard path == "/Applications/Santander.app/Santander" else {
    fatalError("incorrect parent calling, goodbye!")
}

setuid(0)
setgid(0)

guard getuid() == 0 else {
    fatalError("getuid() returned a uid that wasn't 0, in other words, we werent able to get root.")
}

struct Program: ParsableCommand {
    static let configuration: CommandConfiguration = CommandConfiguration(
        subcommands: [
            Create.self,
            Delete.self,
            
            Move.self,
            Copy.self,
            Link.self,
            
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

Program.main()
