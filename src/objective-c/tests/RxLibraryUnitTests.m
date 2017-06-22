/*
 *
 * Copyright 2015 gRPC authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#import <RxLibrary/GRXBufferedPipe.h>
#import <RxLibrary/GRXWriteable.h>
#import <RxLibrary/GRXWriter.h>

// A mock of a GRXSingleValueHandler block that can be queried for how many times it was called and
// what were the last values passed to it.
//
// TODO(jcanizales): Move this to a test util library, and add tests for it.
@interface CapturingSingleValueHandler : NSObject
@property (nonatomic, readonly) void (^block)(id value, NSError *errorOrNil);
@property (nonatomic, readonly) NSUInteger timesCalled;
@property (nonatomic, readonly) id value;
@property (nonatomic, readonly) NSError *errorOrNil;
+ (instancetype)handler;
@end

@implementation CapturingSingleValueHandler
+ (instancetype)handler {
  return [[self alloc] init];
}

- (GRXSingleHandler)block {
  return ^(id value, NSError *errorOrNil) {
    ++_timesCalled;
    _value = value;
    _errorOrNil = errorOrNil;
  };
}
@end

// TODO(jcanizales): Split into one file per tested class.

@interface RxLibraryUnitTests : XCTestCase
@end

@implementation RxLibraryUnitTests

#pragma mark Writeable

- (void)testWriteableSingleHandlerIsCalledForValue {
  // Given:
  CapturingSingleValueHandler *handler = [CapturingSingleValueHandler handler];
  id anyValue = @7;

  // If:
  id<GRXWriteable> writeable = [GRXWriteable writeableWithSingleHandler:handler.block];
  [writeable writeValue:anyValue];
  [writeable writesFinishedWithError:nil];

  // Then:
  XCTAssertEqual(handler.timesCalled, 1);
  XCTAssertEqualObjects(handler.value, anyValue);
  XCTAssertEqualObjects(handler.errorOrNil, nil);
}

- (void)testWriteableSingleHandlerIsCalledForError {
  // Given:
  CapturingSingleValueHandler *handler = [CapturingSingleValueHandler handler];
  NSError *anyError = [NSError errorWithDomain:@"domain" code:7 userInfo:nil];

  // If:
  id<GRXWriteable> writeable = [GRXWriteable writeableWithSingleHandler:handler.block];
  [writeable writesFinishedWithError:anyError];

  // Then:
  XCTAssertEqual(handler.timesCalled, 1);
  XCTAssertEqualObjects(handler.value, nil);
  XCTAssertEqualObjects(handler.errorOrNil, anyError);
}

- (void)testWriteableSingleHandlerIsCalledOnlyOnce_ValueThenError {
  // Given:
  CapturingSingleValueHandler *handler = [CapturingSingleValueHandler handler];
  id anyValue = @7;
  NSError *anyError = [NSError errorWithDomain:@"domain" code:7 userInfo:nil];

  // If:
  id<GRXWriteable> writeable = [GRXWriteable writeableWithSingleHandler:handler.block];
  [writeable writeValue:anyValue];
  [writeable writesFinishedWithError:anyError];

  // Then:
  XCTAssertEqual(handler.timesCalled, 1);
  XCTAssertEqualObjects(handler.value, anyValue);
  XCTAssertEqualObjects(handler.errorOrNil, nil);
}

- (void)testWriteableSingleHandlerIsCalledOnlyOnce_ValueThenValue {
  // Given:
  CapturingSingleValueHandler *handler = [CapturingSingleValueHandler handler];
  id anyValue = @7;

  // If:
  id<GRXWriteable> writeable = [GRXWriteable writeableWithSingleHandler:handler.block];
  [writeable writeValue:anyValue];
  [writeable writeValue:anyValue];
  [writeable writesFinishedWithError:nil];

  // Then:
  XCTAssertEqual(handler.timesCalled, 1);
  XCTAssertEqualObjects(handler.value, anyValue);
  XCTAssertEqualObjects(handler.errorOrNil, nil);
}

- (void)testWriteableSingleHandlerFailsOnEmptyWriter {
  // Given:
  CapturingSingleValueHandler *handler = [CapturingSingleValueHandler handler];

  // If:
  id<GRXWriteable> writeable = [GRXWriteable writeableWithSingleHandler:handler.block];
  [writeable writesFinishedWithError:nil];

  // Then:
  XCTAssertEqual(handler.timesCalled, 1);
  XCTAssertEqualObjects(handler.value, nil);
  XCTAssertNotNil(handler.errorOrNil);
}

#pragma mark BufferedPipe

- (void)testBufferedPipePropagatesValue {
  // Given:
  CapturingSingleValueHandler *handler = [CapturingSingleValueHandler handler];
  id<GRXWriteable> writeable = [GRXWriteable writeableWithSingleHandler:handler.block];
  id anyValue = @7;

  // If:
  GRXBufferedPipe *pipe = [GRXBufferedPipe pipe];
  [pipe startWithWriteable:writeable];
  [pipe writeValue:anyValue];

  // Then:
  XCTAssertEqual(handler.timesCalled, 1);
  XCTAssertEqualObjects(handler.value, anyValue);
  XCTAssertEqualObjects(handler.errorOrNil, nil);
}

- (void)testBufferedPipePropagatesError {
  // Given:
  CapturingSingleValueHandler *handler = [CapturingSingleValueHandler handler];
  id<GRXWriteable> writeable = [GRXWriteable writeableWithSingleHandler:handler.block];
  NSError *anyError = [NSError errorWithDomain:@"domain" code:7 userInfo:nil];

  // If:
  GRXBufferedPipe *pipe = [GRXBufferedPipe pipe];
  [pipe startWithWriteable:writeable];
  [pipe writesFinishedWithError:anyError];

  // Then:
  XCTAssertEqual(handler.timesCalled, 1);
  XCTAssertEqualObjects(handler.value, nil);
  XCTAssertEqualObjects(handler.errorOrNil, anyError);
}

- (void)testBufferedPipeFinishWriteWhilePaused {
  // Given:
  CapturingSingleValueHandler *handler = [CapturingSingleValueHandler handler];
  id<GRXWriteable> writeable = [GRXWriteable writeableWithSingleHandler:handler.block];
  id anyValue = @7;

  // If:
  GRXBufferedPipe *pipe = [GRXBufferedPipe pipe];
  // Write something, then finish
  [pipe writeValue:anyValue];
  [pipe writesFinishedWithError:nil];
  // then start the writeable
  [pipe startWithWriteable:writeable];

  // Then:
  XCTAssertEqual(handler.timesCalled, 1);
  XCTAssertEqualObjects(handler.value, anyValue);
  XCTAssertEqualObjects(handler.errorOrNil, nil);
}

@end