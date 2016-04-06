//
//  Cadmium+ReactiveCocoa.swift
//  FacerCoreUtility
//
//  Copyright (c) 2016-Present Jason Fieldman - https://github.com/jmfieldman/Cadmium
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

import Foundation
import Cadmium
import ReactiveCocoa


private let kCdManagedObjectRACSignal = "kCdManagedObjectRACSignal"
private let kCdManagedObjectRACSink   = "kCdManagedObjectRACSink"

public typealias CdManagedObjectUpdateSignal = Signal<CdManagedObjectUpdateEvent, NoError>

public extension CdManagedObject {
    
    public func rac_updateSignal() -> CdManagedObjectUpdateSignal {
        if let signal = self.userInfo[kCdManagedObjectRACSignal] as? CdManagedObjectUpdateSignal {
            return signal
        }
        
        /* Make the signal */
        let (signal, sink) = CdManagedObjectUpdateSignal.pipe()
        self.userInfo[kCdManagedObjectRACSignal] = signal
        
        /* Insert handler */
        self.updateHandler = { event in
            sink.sendNext(event)
        }
        
        return signal
    }
    
}