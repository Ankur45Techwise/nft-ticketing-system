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

    // State Variables
    uint256 private _eventIds; // Counter for event IDs
    uint256 private _tokenIds; // Counter for token IDs

    // Mappings
    mapping(uint256 => Event) public events; // eventId => Event
    mapping(uint256 => address) public eventOrganizers; // eventId => organizer address
    mapping(uint256 => mapping(uint256 => TicketType)) public ticketTypes; // eventId => (ticketTypeId => TicketType)
    mapping(uint256 => mapping(address => uint256)) public ticketsPurchased; // eventId => (buyer => number of tickets)
    mapping(uint256 => uint256) private _ticketTypeIds; // eventId => number of ticket types

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
}
