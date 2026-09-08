import Testing
@testable import MRRClockCore

@Suite("Stripe pagination")
struct PaginationTests {
    @Test("a single page with has_more false returns its items")
    func singlePage() async throws {
        let expected = [
            Product.stub(id: "prod_1"),
            Product.stub(id: "prod_2"),
            Product.stub(id: "prod_3")
        ]

        let result = try await paginate { _ in
            StripeList.stub(data: expected)
        } id: { $0.id }

        #expect(result.map(\.id) == ["prod_1", "prod_2", "prod_3"])
    }

    @Test("follows has_more across two pages")
    func twoPages() async throws {
        var request = 0

        let result = try await paginate { _ in
            request += 1
            if request == 1 {
                return StripeList.stub(
                    data: [Product.stub(id: "prod_1"), Product.stub(id: "prod_2")],
                    hasMore: true
                )
            }
            return StripeList.stub(data: [Product.stub(id: "prod_3")])
        } id: { $0.id }

        #expect(result.map(\.id) == ["prod_1", "prod_2", "prod_3"])
    }

    @Test("sends starting_after with the last id of the previous page")
    func sendsCursor() async throws {
        var cursors: [String?] = []

        _ = try await paginate { cursor in
            cursors.append(cursor)
            if cursors.count == 1 {
                return StripeList.stub(
                    data: [Product.stub(id: "prod_1"), Product.stub(id: "prod_2")],
                    hasMore: true
                )
            }
            return StripeList.stub(data: [Product.stub(id: "prod_3")])
        } id: { $0.id }

        #expect(cursors.count == 2)
        #expect(cursors[1] == "prod_2")
    }

    @Test("an empty first page returns an empty array")
    func emptyFirstPage() async throws {
        let result: [Product] = try await paginate { _ in
            StripeList.stub(data: [])
        } id: { $0.id }

        #expect(result.isEmpty)
    }

    @Test("throws when has_more is true but data is empty")
    func malformedEmptyPage() async {
        await #expect(throws: StripeError.malformedPage) {
            let _: [Product] = try await paginate { _ in
                StripeList.stub(data: [], hasMore: true)
            } id: { $0.id }
        }
    }

    @Test("throws after 100 pages")
    func pageLimit() async {
        var requests = 0

        await #expect(throws: StripeError.paginationLimitExceeded) {
            let _: [Product] = try await paginate { _ in
                requests += 1
                return StripeList.stub(
                    data: [Product.stub(id: "prod_\(requests)")],
                    hasMore: true
                )
            } id: { $0.id }
        }
        #expect(requests == 100)
    }

    @Test("propagates an error from any page")
    func propagatesPageError() async {
        var requests = 0

        await #expect(throws: TestPageError.failed) {
            let _: [Product] = try await paginate { _ in
                requests += 1
                if requests == 2 { throw TestPageError.failed }
                return StripeList.stub(data: [Product.stub()], hasMore: true)
            } id: { $0.id }
        }
        #expect(requests == 2)
    }
}

private enum TestPageError: Error {
    case failed
}
