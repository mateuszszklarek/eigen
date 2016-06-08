import Quick
import Nimble
import Interstellar
@testable
import Artsy

class LiveAuctionStateManagerSpec: QuickSpec {
    override func spec() {
        var subject: LiveAuctionStateManager!
        var sale: LiveSale!
        let stubbedJWT = ArtsyAPISaleRegistrationStatus.Registered.jwt

        beforeEach {
            OHHTTPStubs.stubJSONResponseForHost("metaphysics*.artsy.net", withResponse: [:])
            // Not sure why ^ is needed, might be worth looking

            sale = testLiveSale()

            let creds = BiddingCredentials(bidderID: "", paddleNumber: "")
            subject = LiveAuctionStateManager(host: "http://localhost", sale: sale, saleArtworks: [], jwt: stubbedJWT, bidderCredentials: creds, socketCommunicatorCreator: test_socketCommunicatorCreator(), stateReconcilerCreator: test_stateReconcilerCreator())
        }

        it("sets its saleID upon initialization") {
            expect(subject.sale) === sale
        }

        it("creates an appropriate socket communicator") {
            expect(mostRecentSocketCommunicator?.host) == "http://localhost"
            expect(mostRecentSocketCommunicator?.jwt.string) == stubbedJWT.string
            expect(mostRecentSocketCommunicator?.causalitySaleID) == "some-random-string-of-nc72bjzj7"
        }

        it("invokes the state reconciler when new snapshot data avaialble") {
            let state = ["hi there!"]
            mostRecentSocketCommunicator?.updatedAuctionState.update(state)

            expect(mostRecentStateReconciler?.mostRecentState as? [String]) == state
        }

        it("invokes current lot updates") {
            let currentLot = ["hi there!"]
            mostRecentSocketCommunicator?.currentLotUpdate.update(currentLot)

            expect(mostRecentStateReconciler?.mostRecentCurrentLotUpdate as? [String]) == currentLot
        }

        it("invokes lot event updates") {
            let lotEvent = ["hi there!"]
            mostRecentSocketCommunicator?.lotUpdateBroadcasts.update(lotEvent)

            expect(mostRecentStateReconciler?.mostRecentEventBroadcast as? [String]) == lotEvent
        }

        describe("bidderStatus") {

            it("handles being logged out") {
                let jwt = ArtsyAPISaleRegistrationStatus.NotLoggedIn.jwt

                let creds = BiddingCredentials(bidderID: "", paddleNumber: "")

                subject = LiveAuctionStateManager(host: "http://localhost", sale: sale, saleArtworks: [], jwt: jwt, bidderCredentials: creds, socketCommunicatorCreator: test_socketCommunicatorCreator(), stateReconcilerCreator: test_stateReconcilerCreator())

                expect(subject.bidderStatus) == ArtsyAPISaleRegistrationStatus.NotLoggedIn
            }

            it("handles being logged in and not registered") {

                let jwt = ArtsyAPISaleRegistrationStatus.NotRegistered.jwt
                let creds = BiddingCredentials(bidderID: "", paddleNumber: "")

                subject = LiveAuctionStateManager(host: "http://localhost", sale: sale, saleArtworks: [], jwt: jwt, bidderCredentials: creds, socketCommunicatorCreator: test_socketCommunicatorCreator(), stateReconcilerCreator: test_stateReconcilerCreator())

                expect(subject.bidderStatus) == ArtsyAPISaleRegistrationStatus.NotRegistered

            }

            it("handles being logged in and register") {
                let jwt = ArtsyAPISaleRegistrationStatus.Registered.jwt

                let creds = BiddingCredentials(bidderID: "", paddleNumber: "")
                subject = LiveAuctionStateManager(host: "http://localhost", sale: sale, saleArtworks: [], jwt: jwt, bidderCredentials: creds, socketCommunicatorCreator: test_socketCommunicatorCreator(), stateReconcilerCreator: test_stateReconcilerCreator())

                expect(subject.bidderStatus) == ArtsyAPISaleRegistrationStatus.Registered
            }
        }
    }
}


func test_socketCommunicatorCreator() -> LiveAuctionStateManager.SocketCommunicatorCreator {
    return { host, saleID, jwt in
        return Test_SocketCommunicator(host: host, causalitySaleID: saleID, jwt: jwt)
    }
}

func test_stateReconcilerCreator() -> LiveAuctionStateManager.StateReconcilerCreator {
    return { saleArtworks in
        return Test_StateRecociler()
    }
}

var mostRecentSocketCommunicator: Test_SocketCommunicator?

class Test_SocketCommunicator: LiveAuctionSocketCommunicatorType {

    let host: String
    let causalitySaleID: String
    let jwt: JWT

    init(host: String, causalitySaleID: String, jwt: JWT) {
        self.host = host
        self.causalitySaleID = causalitySaleID
        self.jwt = jwt

        mostRecentSocketCommunicator = self
    }

    let updatedAuctionState = Observable<AnyObject>()
    let lotUpdateBroadcasts = Observable<AnyObject>()
    let currentLotUpdate = Observable<AnyObject>()
    let postEventResponses = Observable<AnyObject>()
    let socketConnectionSignal = Observable<Bool>()
    let operatorConnectedSignal = Observable<AnyObject>()
    func bidOnLot(lotID: String, amountCents: UInt64, bidderID: String, bidUUID: String) { }
    func leaveMaxBidOnLot(lotID: String, amountCents: UInt64, bidderID: String, bidUUID: String) { }
}

var mostRecentStateReconciler: Test_StateRecociler?

class Test_StateRecociler: LiveAuctionStateReconcilerType {
    var mostRecentState: AnyObject?
    var mostRecentEventBroadcast: AnyObject?
    var mostRecentCurrentLotUpdate: AnyObject?
    var mostRecentEvent: AnyObject?
    var debugAllEventsSignal = Observable<LotEventJSON>()

    init() {
        mostRecentStateReconciler = self
    }

    func updateState(state: AnyObject) {
        mostRecentState = state
    }

    func processNewEvents(event: AnyObject) {
        mostRecentEvent = event
    }

    func processLotEventBroadcast(broadcast: AnyObject) {
        mostRecentEventBroadcast = broadcast
    }

    func processCurrentLotUpdate(update: AnyObject) {
        mostRecentCurrentLotUpdate = update
    }
    
    var newLotsSignal: Observable<[LiveAuctionLotViewModelType]> { return Observable() }
    var currentLotSignal: Observable<LiveAuctionLotViewModelType?> { return Observable() }
    var saleSignal: Observable<LiveAuctionViewModelType> { return Observable() }
}
