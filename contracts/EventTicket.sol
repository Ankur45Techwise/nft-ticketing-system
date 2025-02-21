// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract EventTicket is ERC721, Ownable, ReentrancyGuard {
    // Constructor
    constructor() ERC721("EventTicket", "ETKT") Ownable(msg.sender) {}

    // Structs
    struct Event {
        string name;
        string description;
        uint256 date;
        uint256 basePrice;
        uint256 maxTickets;
        uint256 ticketsSold;
        bool isActive;
    }

    struct TicketType {
        string name;
        uint256 price;
        uint256 maxSupply;
        uint256 currentSupply;
    }

    struct Auction {
        uint256 eventId;
        uint256 ticketTypeId;
        address highestBidder;
        uint256 highestBid;
        uint256 endTime;
        bool active;
    }

    // State Variables
    uint256 private _eventIds; // Counter for event IDs
    uint256 private _tokenIds; // Counter for token IDs
    uint256 private _auctionIds; // Counter for auction IDs

    // Mappings
    mapping(uint256 => Event) public events; // eventId => Event
    mapping(uint256 => address) public eventOrganizers; // eventId => organizer address
    mapping(uint256 => mapping(uint256 => TicketType)) public ticketTypes; // eventId => (ticketTypeId => TicketType)
    mapping(uint256 => mapping(address => uint256)) public ticketsPurchased; // eventId => (buyer => number of tickets)
    mapping(uint256 => uint256) private _ticketTypeIds; // eventId => number of ticket types
    mapping(address => uint256) public lastPurchaseTime; // Last purchase timestamp for each user
    mapping(uint256 => Auction) public auctions; // auctionId => Auction

    uint256 public constant COOLDOWN_PERIOD = 1 hours; // Cooldown period between purchases
    uint256 public constant MAX_TICKETS_PER_PURCHASE = 5; // Max tickets allowed per purchase

    // Events
    event EventCreated(
        uint256 indexed eventId,
        string name,
        uint256 date,
        address organizer
    );

    event TicketTypeAdded(
        uint256 indexed eventId,
        uint256 ticketTypeId,
        string name,
        uint256 price
    );

    event TicketPurchased(
        uint256 indexed eventId,
        uint256 indexed ticketTypeId,
        address buyer,
        uint256 quantity,
        uint256 totalPrice
    );

    event TicketTransferred(
        uint256 indexed eventId,
        uint256 indexed ticketTypeId,
        address from,
        address to,
        uint256 quantity
    );

    event AuctionStarted(
        uint256 indexed auctionId,
        uint256 indexed eventId,
        uint256 indexed ticketTypeId,
        uint256 startingPrice,
        uint256 endTime
    );

    event BidPlaced(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 bidAmount
    );

    event AuctionEnded(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 winningBid
    );

    // Modifiers
    modifier onlyEventOrganizer(uint256 eventId) {
        require(
            eventOrganizers[eventId] == msg.sender,
            "Only event organizer can call this function"
        );
        _;
    }

    modifier eventExists(uint256 eventId) {
        require(events[eventId].isActive, "Event does not exist");
        _;
    }

    // Event Creation Functions
    function createEvent(
        string memory name,
        string memory description,
        uint256 date,
        uint256 basePrice,
        uint256 maxTickets
    ) public returns (uint256) {
        require(date > block.timestamp, "Event date must be in the future");
        require(maxTickets > 0, "Max tickets must be greater than 0");
        require(bytes(name).length > 0, "Event name cannot be empty");

        uint256 eventId = _eventIds++;

        events[eventId] = Event({
            name: name,
            description: description,
            date: date,
            basePrice: basePrice,
            maxTickets: maxTickets,
            ticketsSold: 0,
            isActive: true
        });

        eventOrganizers[eventId] = msg.sender;

        emit EventCreated(eventId, name, date, msg.sender);
        return eventId;
    }

    function addTicketType(
        uint256 eventId,
        string memory name,
        uint256 price,
        uint256 maxSupply
    ) public onlyEventOrganizer(eventId) eventExists(eventId) {
        require(bytes(name).length > 0, "Ticket type name cannot be empty");
        require(price > 0, "Price must be greater than 0");
        require(maxSupply > 0, "Max supply must be greater than 0");

        // Get new ticket type ID and increment counter
        uint256 ticketTypeId = _ticketTypeIds[eventId];
        _ticketTypeIds[eventId] = ticketTypeId + 1;

        // Create new ticket type
        ticketTypes[eventId][ticketTypeId] = TicketType({
            name: name,
            price: price,
            maxSupply: maxSupply,
            currentSupply: 0
        });

        emit TicketTypeAdded(eventId, ticketTypeId, name, price);
    }

    function updateEvent(
        uint256 eventId,
        string memory name,
        string memory description,
        uint256 date,
        uint256 basePrice
    ) public onlyEventOrganizer(eventId) eventExists(eventId) {
        require(date > block.timestamp, "Event date must be in the future");
        require(
            events[eventId].ticketsSold == 0,
            "Cannot update event after tickets are sold"
        );

        Event storage eventToUpdate = events[eventId];
        eventToUpdate.name = name;
        eventToUpdate.description = description;
        eventToUpdate.date = date;
        eventToUpdate.basePrice = basePrice;
    }

    // View Functions
    function getEvent(
        uint256 eventId
    )
        public
        view
        eventExists(eventId)
        returns (
            string memory name,
            string memory description,
            uint256 date,
            uint256 basePrice,
            uint256 maxTickets,
            uint256 ticketsSold,
            bool isActive
        )
    {
        Event storage event_ = events[eventId];
        return (
            event_.name,
            event_.description,
            event_.date,
            event_.basePrice,
            event_.maxTickets,
            event_.ticketsSold,
            event_.isActive
        );
    }

    function getEventCount() public view returns (uint256) {
        return _eventIds; // Return the total number of events created
    }

    function getTicketType(
        uint256 eventId,
        uint256 ticketTypeId
    )
        public
        view
        eventExists(eventId)
        returns (
            string memory name,
            uint256 price,
            uint256 maxSupply,
            uint256 currentSupply
        )
    {
        TicketType storage ticketType = ticketTypes[eventId][ticketTypeId];
        require(
            bytes(ticketType.name).length > 0,
            "Ticket type does not exist"
        );

        return (
            ticketType.name,
            ticketType.price,
            ticketType.maxSupply,
            ticketType.currentSupply
        );
    }

    function getEventTicketTypes(
        uint256 eventId
    ) public view eventExists(eventId) returns (uint256) {
        uint256 count = 0;
        while (bytes(ticketTypes[eventId][count].name).length > 0) {
            count++;
        }
        return count;
    }

    function isEventOrganizer(
        uint256 eventId,
        address account
    ) public view returns (bool) {
        return eventOrganizers[eventId] == account;
    }

    function purchaseTicket(
        uint256 eventId,
        uint256 ticketTypeId,
        uint256 quantity
    ) public payable eventExists(eventId) {
        TicketType storage ticketType = ticketTypes[eventId][ticketTypeId];
        require(
            ticketType.currentSupply + quantity <= ticketType.maxSupply,
            "Not enough tickets available"
        );
        require(
            msg.value == ticketType.price * quantity,
            "Incorrect Ether value sent"
        );

        // Anti-bot measures
        require(
            quantity <= MAX_TICKETS_PER_PURCHASE,
            "Cannot purchase more than 5 tickets at once"
        );
        require(
            block.timestamp >= lastPurchaseTime[msg.sender] + COOLDOWN_PERIOD,
            "Please wait before making another purchase"
        );

        // Update ticket type supply
        ticketType.currentSupply += quantity;

        // Update tickets purchased by the user
        ticketsPurchased[eventId][msg.sender] += quantity;

        // Update total tickets sold for the event
        events[eventId].ticketsSold += quantity;

        // Transfer Ether to the contract owner (event organizer)
        payable(eventOrganizers[eventId]).transfer(msg.value);

        // Update last purchase time
        lastPurchaseTime[msg.sender] = block.timestamp;

        // Emit TicketPurchased event
        emit TicketPurchased(
            eventId,
            ticketTypeId,
            msg.sender,
            quantity,
            msg.value
        );
    }

    function transferTicket(
        uint256 eventId,
        uint256 ticketTypeId,
        address to,
        uint256 quantity
    ) public eventExists(eventId) {
        require(
            ticketsPurchased[eventId][msg.sender] >= quantity,
            "Not enough tickets to transfer"
        );

        // Update tickets purchased count
        ticketsPurchased[eventId][msg.sender] -= quantity;
        ticketsPurchased[eventId][to] += quantity;

        // Emit TicketTransferred event
        emit TicketTransferred(eventId, ticketTypeId, msg.sender, to, quantity);

        // Logic to handle NFT transfer (if applicable)
        // For example, if using ERC721, you'd call _transfer() here
    }

    // Function to start an auction
    function startAuction(
        uint256 eventId,
        uint256 ticketTypeId,
        uint256 startingPrice,
        uint256 duration
    ) public onlyEventOrganizer(eventId) eventExists(eventId) {
        require(duration > 0, "Duration must be greater than 0");

        uint256 auctionId = _auctionIds++;
        uint256 endTime = block.timestamp + duration;

        auctions[auctionId] = Auction({
            eventId: eventId,
            ticketTypeId: ticketTypeId,
            highestBidder: address(0),
            highestBid: startingPrice,
            endTime: endTime,
            active: true
        });

        emit AuctionStarted(
            auctionId,
            eventId,
            ticketTypeId,
            startingPrice,
            endTime
        );
    }

    // Function to place a bid
    function placeBid(uint256 auctionId) public payable {
        Auction storage auction = auctions[auctionId];
        require(auction.active, "Auction is not active");
        require(block.timestamp < auction.endTime, "Auction has ended");
        require(
            msg.value > auction.highestBid,
            "Bid must be higher than the current highest bid"
        );

        // Refund the previous highest bidder
        if (auction.highestBidder != address(0)) {
            payable(auction.highestBidder).transfer(auction.highestBid);
        }

        // Update auction details
        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;

        emit BidPlaced(auctionId, msg.sender, msg.value);
    }

    // Function to end the auction
    function endAuction(uint256 auctionId) public {
        Auction storage auction = auctions[auctionId];
        require(auction.active, "Auction is not active");
        require(
            block.timestamp >= auction.endTime,
            "Auction has not ended yet"
        );

        auction.active = false;

        // Transfer ticket to the highest bidder if there is one
        if (auction.highestBidder != address(0)) {
            // Logic to transfer the ticket (if using ERC721, call _transfer())
            // Example: _transfer(address(this), auction.highestBidder, ticketId);

            emit AuctionEnded(
                auctionId,
                auction.highestBidder,
                auction.highestBid
            );
        }
    }
}
