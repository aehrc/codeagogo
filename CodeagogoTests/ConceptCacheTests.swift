// Copyright 2026 Commonwealth Scientific and Industrial Research Organisation (CSIRO)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import XCTest
@testable import Codeagogo

/// Tests for the thread-safe ConceptCache actor
final class ConceptCacheTests: XCTestCase {

    // MARK: - Basic Cache Operations

    func testCacheSetAndGet() async {
        let cache = TestableConceptCache()
        let result = makeConceptResult(id: "123456789")

        await cache.set("123456789", result: result)
        let cached = await cache.get("123456789", ttl: 3600)

        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.conceptId, "123456789")
    }

    func testCacheMiss() async {
        let cache = TestableConceptCache()

        let cached = await cache.get("nonexistent", ttl: 3600)

        XCTAssertNil(cached)
    }

    func testCacheExpiration() async {
        let cache = TestableConceptCache()
        let result = makeConceptResult(id: "123456789")

        await cache.set("123456789", result: result)

        // With a TTL of 0, should be expired immediately
        let cached = await cache.get("123456789", ttl: 0)

        XCTAssertNil(cached, "Cache entry should be expired with TTL of 0")
    }

    func testCacheOverwrite() async {
        let cache = TestableConceptCache()
        let result1 = makeConceptResult(id: "123456789", fsn: "Original term")
        let result2 = makeConceptResult(id: "123456789", fsn: "Updated term")

        await cache.set("123456789", result: result1)
        await cache.set("123456789", result: result2)

        let cached = await cache.get("123456789", ttl: 3600)

        XCTAssertEqual(cached?.fsn, "Updated term")
    }

    // MARK: - Concurrent Access Tests

    func testConcurrentReads() async {
        let cache = TestableConceptCache()
        let result = makeConceptResult(id: "123456789")
        await cache.set("123456789", result: result)

        // Perform many concurrent reads
        await withTaskGroup(of: ConceptResult?.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    await cache.get("123456789", ttl: 3600)
                }
            }

            var results: [ConceptResult?] = []
            for await result in group {
                results.append(result)
            }

            // All reads should succeed
            XCTAssertEqual(results.count, 100)
            XCTAssertTrue(results.allSatisfy { $0?.conceptId == "123456789" })
        }
    }

    func testConcurrentWrites() async {
        let cache = TestableConceptCache()

        // Perform many concurrent writes
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let result = self.makeConceptResult(id: "concept\(i)")
                    await cache.set("concept\(i)", result: result)
                }
            }
        }

        // Verify all writes succeeded
        for i in 0..<100 {
            let cached = await cache.get("concept\(i)", ttl: 3600)
            XCTAssertNotNil(cached, "concept\(i) should be cached")
        }
    }

    func testConcurrentReadWrite() async {
        let cache = TestableConceptCache()

        // Mix reads and writes concurrently
        await withTaskGroup(of: Void.self) { group in
            // Writers
            for i in 0..<50 {
                group.addTask {
                    let result = self.makeConceptResult(id: "\(i)")
                    await cache.set("\(i)", result: result)
                }
            }

            // Readers (may or may not find entries)
            for i in 0..<50 {
                group.addTask {
                    _ = await cache.get("\(i)", ttl: 3600)
                }
            }
        }

        // Test passes if no crashes occur (actor provides thread safety)
    }

    // MARK: - TTL Tests

    func testValidTTL() async {
        let cache = TestableConceptCache()
        let result = makeConceptResult(id: "123456789")

        await cache.set("123456789", result: result)

        // With large TTL, should still be valid
        let cached = await cache.get("123456789", ttl: 86400) // 24 hours

        XCTAssertNotNil(cached)
    }

    func testDifferentTTLsForSameEntry() async {
        let cache = TestableConceptCache()
        let result = makeConceptResult(id: "123456789")

        await cache.set("123456789", result: result)

        // Same entry, different TTL checks
        let withLargeTTL = await cache.get("123456789", ttl: 86400)
        let withSmallTTL = await cache.get("123456789", ttl: 0)

        XCTAssertNotNil(withLargeTTL)
        XCTAssertNil(withSmallTTL)
    }

    // MARK: - LRU Eviction Tests

    func testCacheSizeLimit() async {
        let cache = TestableConceptCache(maxSize: 5)

        // Add 5 entries (at capacity)
        for i in 0..<5 {
            await cache.set("concept\(i)", result: makeConceptResult(id: "concept\(i)"))
        }

        let countAtCapacity = await cache.count()
        XCTAssertEqual(countAtCapacity, 5)

        // Add a 6th entry - should trigger eviction
        await cache.set("concept5", result: makeConceptResult(id: "concept5"))

        let countAfterEviction = await cache.count()
        XCTAssertEqual(countAfterEviction, 5, "Cache size should remain at max")
    }

    func testLRUEviction() async {
        let cache = TestableConceptCache(maxSize: 3)

        // Add 3 entries
        await cache.set("A", result: makeConceptResult(id: "A"))
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms delay
        await cache.set("B", result: makeConceptResult(id: "B"))
        try? await Task.sleep(nanoseconds: 10_000_000)
        await cache.set("C", result: makeConceptResult(id: "C"))

        // Access A to make it more recently used
        _ = await cache.get("A", ttl: 3600)
        try? await Task.sleep(nanoseconds: 10_000_000)

        // Add D - should evict B (least recently used)
        await cache.set("D", result: makeConceptResult(id: "D"))

        let cachedA = await cache.get("A", ttl: 3600)
        let cachedB = await cache.get("B", ttl: 3600)
        let cachedC = await cache.get("C", ttl: 3600)
        let cachedD = await cache.get("D", ttl: 3600)

        XCTAssertNotNil(cachedA, "A should still be cached (was accessed)")
        XCTAssertNil(cachedB, "B should be evicted (least recently used)")
        XCTAssertNotNil(cachedC, "C should still be cached")
        XCTAssertNotNil(cachedD, "D should be cached")
    }

    func testUpdateDoesNotCountAsNewEntry() async {
        let cache = TestableConceptCache(maxSize: 3)

        // Add 3 entries
        await cache.set("A", result: makeConceptResult(id: "A"))
        await cache.set("B", result: makeConceptResult(id: "B"))
        await cache.set("C", result: makeConceptResult(id: "C"))

        // Update A with new data - should not trigger eviction
        await cache.set("A", result: makeConceptResult(id: "A", fsn: "Updated"))

        let count = await cache.count()
        let cachedB = await cache.get("B", ttl: 3600)
        let cachedC = await cache.get("C", ttl: 3600)
        let updated = await cache.get("A", ttl: 3600)

        XCTAssertEqual(count, 3)
        XCTAssertNotNil(cachedB, "B should still be cached")
        XCTAssertNotNil(cachedC, "C should still be cached")
        XCTAssertEqual(updated?.fsn, "Updated")
    }

    func testExpiredEntryRemoval() async {
        let cache = TestableConceptCache(maxSize: 5)
        let result = makeConceptResult(id: "123456789")

        await cache.set("123456789", result: result)
        let countBefore = await cache.count()
        XCTAssertEqual(countBefore, 1)

        // Access with 0 TTL should remove the expired entry
        let expired = await cache.get("123456789", ttl: 0)
        let countAfter = await cache.count()

        XCTAssertNil(expired)
        XCTAssertEqual(countAfter, 0, "Expired entry should be removed")
    }

    // MARK: - Helpers

    private func makeConceptResult(
        id: String,
        fsn: String = "Test term (test)",
        pt: String = "Test term",
        active: Bool = true
    ) -> ConceptResult {
        ConceptResult(
            conceptId: id,
            branch: "MAIN",
            fsn: fsn,
            pt: pt,
            active: active,
            effectiveTime: "20240101",
            moduleId: "900000000000207008"
        )
    }
}

// MARK: - Testable Cache Implementation

/// A testable version of ConceptCache with LRU eviction (mirrors the implementation in OntoserverClient)
private actor TestableConceptCache {
    private struct CacheEntry {
        let result: ConceptResult
        let createdAt: Date
        var lastAccessedAt: Date
    }

    private var storage: [String: CacheEntry] = [:]
    private let maxSize: Int

    init(maxSize: Int = 100) {
        self.maxSize = maxSize
    }

    func get(_ conceptId: String, ttl: TimeInterval) -> ConceptResult? {
        guard var entry = storage[conceptId],
              Date().timeIntervalSince(entry.createdAt) < ttl else {
            // Remove expired entry if it exists
            storage.removeValue(forKey: conceptId)
            return nil
        }
        // Update last accessed time for LRU tracking
        entry.lastAccessedAt = Date()
        storage[conceptId] = entry
        return entry.result
    }

    func set(_ conceptId: String, result: ConceptResult) {
        // If at capacity and this is a new entry, evict the least recently used
        if storage[conceptId] == nil && storage.count >= maxSize {
            evictLeastRecentlyUsed()
        }

        let now = Date()
        storage[conceptId] = CacheEntry(
            result: result,
            createdAt: now,
            lastAccessedAt: now
        )
    }

    private func evictLeastRecentlyUsed() {
        guard let lruKey = storage.min(by: { $0.value.lastAccessedAt < $1.value.lastAccessedAt })?.key else {
            return
        }
        storage.removeValue(forKey: lruKey)
    }

    func count() -> Int {
        storage.count
    }
}
