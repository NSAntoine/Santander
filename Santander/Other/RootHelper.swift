//
//  FSOperation.swift
//  Santander
//
//  Created by Serena on 15/09/2022
//


import Foundation
@_exported import FSOperations // export FSOperations to rest of Santander module
import NSTaskBridge

struct RootConf: RootHelperConfiguration {
    private init() {}
    
    static let shared = RootConf()
    
    func contents(of path: URL) throws -> [URL] {
        let spawn = try spawn(command: try rootHelperURL(), args: ["get-contents", path.path])
        return spawn.standardOutput.components(separatedBy: " ").map(URL.init(fileURLWithPath:))
    }
    
    private func rootHelperURL() throws -> URL {
        guard let rootHelperURL = Bundle.main.url(forAuxiliaryExecutable: "RootHelper"),
              FileManager.default.fileExists(atPath: rootHelperURL.path) else {
            throw Errors.rootHelperUnavailable
        }
        
        return rootHelperURL
    }
    
    func perform(_ operation: FSOperation) throws {
        let ret: Output
        if case let .writeData(_, data) = operation {
            ret = try spawn(command: try rootHelperURL(), args: operation.commandLineInvokation, standardInputData: data)
        } else {
            ret = try spawn(command: try rootHelperURL(), args: operation.commandLineInvokation)
        }
        
        guard ret.status == 0 else {
            throw Errors.otherError(description: "Root helper returned non-zero status, error: \(ret.standardError)")
        }
    }
    
    /*
     shamelessly copied from
     https://github.com/elihwyma/Pogo/blob/c25186f7a554407563174b32f3a34c21aedba22b/Pogo/CommandRunner.swift#L11
     Modified tho
     */
    
    func spawn(command: URL, args: [String], root: Bool = true, standardInputData: Data? = nil) throws -> Output {
        var stdoutPipe: [Int32] = [0, 0]
        var stderrPipe: [Int32] = [0, 0]
        //var stdinPipe:  [Int32] = [0, 0]
        
        let bufsiz = Int(BUFSIZ)
        
        pipe(&stdoutPipe)
        pipe(&stderrPipe)
        //pipe(&stdinPipe)
        
        guard fcntl(stdoutPipe[0], F_SETFL, O_NONBLOCK) != -1,
              fcntl(stderrPipe[0], F_SETFL, O_NONBLOCK) != -1/*,
              fcntl(stdinPipe[0],  F_SETFL, O_NONBLOCK) != -1*/ else {
            let currentErrnoString = String(cString: strerror(errno))
            throw Errors.otherError(description: "fnctl failed?! Error: \(currentErrnoString)")
        }
        
        /*
        if let standardInputData {
            standardInputData.withUnsafeBytes { rawBufferPtr in
                let base = rawBufferPtr.baseAddress!
                let writeAmount = write(stdinPipe[1], base, standardInputData.count)
                NSLog("RootHelper: writeAmount: \(writeAmount)")
            }
        }
         */
        
        let args: [String] = [command.lastPathComponent] + args
        let argv: [UnsafeMutablePointer<CChar>?] = args.map { $0.withCString(strdup) }
        defer { for case let arg? in argv { free(arg) } }
        
        var fileActions: posix_spawn_file_actions_t?
        if root {
            posix_spawn_file_actions_init(&fileActions)
            posix_spawn_file_actions_addclose(&fileActions, stdoutPipe[0])
            posix_spawn_file_actions_addclose(&fileActions, stderrPipe[0])
            //posix_spawn_file_actions_addclose(&fileActions, stdinPipe[0])
            
            posix_spawn_file_actions_adddup2(&fileActions, stdoutPipe[1], STDOUT_FILENO)
            posix_spawn_file_actions_adddup2(&fileActions, stderrPipe[1], STDERR_FILENO)
            //posix_spawn_file_actions_adddup2(&fileActions, stdinPipe[0],  STDIN_FILENO)
            
            posix_spawn_file_actions_addclose(&fileActions, stdoutPipe[1])
            posix_spawn_file_actions_addclose(&fileActions, stderrPipe[1])
            //posix_spawn_file_actions_addclose(&fileActions, stdinPipe[1])
        }
        
        var attr: posix_spawnattr_t?
        posix_spawnattr_init(&attr)
        posix_spawnattr_set_persona_np(&attr, 99, UInt32(POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE))
        posix_spawnattr_set_persona_uid_np(&attr, 0)
        posix_spawnattr_set_persona_gid_np(&attr, 0)
        
        let env: [String]
        if #available(iOS 15, *) {
            // Rootless
            env = [ "PATH=/usr/local/sbin:/var/jb/usr/local/sbin:/usr/local/bin:/var/jb/usr/local/bin:/usr/sbin:/var/jb/usr/sbin:/usr/bin:/var/jb/usr/bin:/sbin:/var/jb/sbin:/bin:/var/jb/bin:/usr/bin/X11:/var/jb/usr/bin/X11:/usr/games:/var/jb/usr/games"
            ]
        } else {
            env = ["PATH=/usr/bin:/usr/local/bin:/bin:/usr/sbin"]
        }
        
        let proenv = env.map { $0.withCString(strdup) }
        defer {
            for case let pro? in proenv {
                free(pro)
            }
        }
        
        var pid: pid_t = 0
        let spawnStatus = posix_spawn(&pid, command.path, &fileActions, &attr, argv + [nil], proenv + [nil])
        guard spawnStatus == 0 else {
            NSLog("spawnStatus error: \(String(cString: strerror(errno)))")
            throw Errors.failedToSpawnHelper
        }
        
        /*
        if let standardInputData {
            standardInputData.withUnsafeBytes { rawBufferPtr in
                let base = rawBufferPtr.baseAddress!
                let writeAmount = write(stdinPipe[1], base, standardInputData.count)
                NSLog("RootHelper: writeAmount: \(writeAmount)")
            }
        }
         */
        
        close(stdoutPipe[1])
        close(stderrPipe[1])
        //close(stdinPipe[1])
        
        var stdoutStr = ""
        var stderrStr = ""
        
        let mutex = DispatchSemaphore(value: 0)
        
        let readQueue = DispatchQueue(label: "com.serena.Santander.RootHelper",
                                      qos: .userInitiated,
                                      attributes: .concurrent,
                                      autoreleaseFrequency: .inherit,
                                      target: nil)
        
        let stdoutSource = DispatchSource.makeReadSource(fileDescriptor: stdoutPipe[0], queue: readQueue)
        let stderrSource = DispatchSource.makeReadSource(fileDescriptor: stderrPipe[0], queue: readQueue)
        
        stdoutSource.setCancelHandler {
            close(stdoutPipe[0])
            mutex.signal()
        }
        
        stderrSource.setCancelHandler {
            close(stderrPipe[0])
            mutex.signal()
        }
        
        stdoutSource.setEventHandler {
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufsiz)
            defer { buffer.deallocate() }
            
            let bytesRead = read(stdoutPipe[0], buffer, bufsiz)
            guard bytesRead > 0 else {
                if bytesRead == -1 && errno == EAGAIN {
                    return
                }
                
                stdoutSource.cancel()
                return
            }
            
            let array = Array(UnsafeBufferPointer(start: buffer, count: bytesRead)) + [UInt8(0)]
            array.withUnsafeBufferPointer { ptr in
                let str = String(cString: unsafeBitCast(ptr.baseAddress, to: UnsafePointer<CChar>.self))
                stdoutStr += str
            }
        }
        
        stderrSource.setEventHandler {
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufsiz)
            defer { buffer.deallocate() }
            
            let bytesRead = read(stderrPipe[0], buffer, bufsiz)
            guard bytesRead > 0 else {
                if bytesRead == -1 && errno == EAGAIN {
                    return
                }
                
                stderrSource.cancel()
                return
            }
            
            let array = Array(UnsafeBufferPointer(start: buffer, count: bytesRead)) + [UInt8(0)]
            array.withUnsafeBufferPointer { ptr in
                let str = String(cString: unsafeBitCast(ptr.baseAddress, to: UnsafePointer<CChar>.self))
                stderrStr += str
            }
        }
        
        stdoutSource.resume()
        stderrSource.resume()
        
        mutex.wait()
        mutex.wait()
        
        var status: Int32 = 0
        waitpid(pid, &status, 0)
        return Output(status: status, standardOutput: stdoutStr, standardError: stderrStr)
    }
    
    struct Output {
        let status: CInt
        let standardOutput: String
        let standardError: String
    }
    
    var useRootHelper: Bool {
        return UserPreferences.rootHelperIsEnabled
    }
    
    private enum Errors: Error, LocalizedError, CustomStringConvertible {
        case rootHelperUnavailable
        case unableToReadHelperOutput
        case failedToSpawnHelper
        case otherError(description: String)
        
        var description: String {
            switch self {
            case .rootHelperUnavailable:
                return "Root Helper unavailable? is your install messed up?"
            case .unableToReadHelperOutput:
                return "Unable to read root helper output"
            case .failedToSpawnHelper:
                return "Failed to spawn root helper"
            case .otherError(let description):
                return description
            }
        }
        
        var errorDescription: String? {
            description
        }
    }
}
