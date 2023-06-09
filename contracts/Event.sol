// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "./HederaResponseCodes.sol";
import "./IHederaTokenService.sol";
import "./HederaTokenService.sol";
import "./ExpiryHelper.sol";
import "./KeyHelper.sol";

import {OpenSection, OpenSectionMap, OpenSectionIterableMapping} from "./OpenSection.sol";
import {ReservedSection, ReservedSectionMap, ReservedSectionIterableMapping} from "./ReservedSection.sol";
import {ReservedSeat, ReservedSeatMap, ReservedSeatIterableMapping} from "./ReservedSeat.sol";

contract Event is ExpiryHelper, KeyHelper, HederaTokenService {
    // usings
    using OpenSectionIterableMapping for OpenSectionMap;
    using ReservedSectionIterableMapping for ReservedSectionMap;
    using ReservedSeatIterableMapping for ReservedSeatMap;

    // types

    // constants

    // properties
    address public owner;
    address public venue;
    address public entertainer;
    address public tokenAddress;
    bool public venueSigned;
    bool public entertainerSigned;
    bool public ticketSalesEnabled;
    uint256 public eventDateTime;
    uint256 public venueFlatFee;
    uint8 public venuePercentage;
    int256 public defaultTicketPrice;
    OpenSectionMap openSections;
    ReservedSectionMap reservedSections;
    ReservedSeatMap reservedSeats;

    // constructor
    constructor(address _venue, address _entertainer) {
        require(_venue != address(0) && _entertainer != address(0), "Venue and entertainer are required");
        owner = msg.sender;
        venue = _venue;
        entertainer = _entertainer;
        venueSigned = false;
        entertainerSigned = false;
        ticketSalesEnabled = false;
    }

    // access modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Unauthorized");
        _;
    }

    modifier onlyVenue() {
        require(msg.sender == venue, "Unauthorized");
        _;
    }

    modifier onlyEntertainer() {
        require(msg.sender == entertainer, "Unauthorized");
        _;
    }

    modifier onlyAdmin() {
        require(
            msg.sender == venue || msg.sender == entertainer,
            "Unauthorized"
        );
        _;
    }

    modifier finalized() {
        require(
            venueSigned && entertainerSigned,
            "This action requires a finalized contract"
        );
        _;
    }

    modifier notFinalized() {
        require(
            !venueSigned || !entertainerSigned,
            "This contract is already finalized"
        );
        _;
    }

    modifier readyToSign() {
        require(
            eventDateTime > 0 && defaultTicketPrice != 0,
            "Contract not ready to sign"
        );
        _;
    }

    modifier resetSignatures() {
        _;
        venueSigned = false;
        entertainerSigned = false;
    }

    modifier tokenCreated() {
      require(tokenAddress != address(0), "NFT Collection not created yet");
      _;
    }

    modifier salesEnabled() {
        require(ticketSalesEnabled, "Ticket sales are not enabled");
        _;
    }

    // public getters
    function getOpenSectionKeys()
        public
        view
        returns (string[] memory)
    {
        return openSections.keys;
    }

    function getOpenSection(
        string memory _key
    ) public view returns (OpenSection memory) {
        return openSections.get(_key);
    }

    function getReservedSectionKeys()
        public
        view
        returns (string[] memory)
    {
        return reservedSections.keys;
    }

    function getReservedSection(
        string memory _key
    ) public view returns (ReservedSection memory) {
        return reservedSections.get(_key);
    }

    function getReservedSeat(
        string memory _key
    ) public view returns (ReservedSeat memory) {
        return reservedSeats.get(_key);
    }

    function isSeatAvailable(
        string calldata _section,
        string calldata _row,
        string calldata _seat
    ) public view returns (bool) {
        OpenSection memory openSection = getOpenSection(_section);
        if (openSection.maxCapacity > 0) {
          return (openSection.remainingCapacity > 0);
        }
        string memory seatKey = buildSeatKey(_section, _row, _seat);
        ReservedSeat memory reservedSeat = getReservedSeat(seatKey);
        return (reservedSeat.serial == 0);
    }

    function getSeatTicketPrice(
        string calldata _section,
        string calldata _row,
        string calldata _seat
    ) public view returns (int256) {
        int256 ticketPrice = getOpenSectionTicketPrice(_section);
        if (ticketPrice != 0) {
            return ticketPrice;
        }

        ticketPrice = getReservedSectionTicketPrice(
            buildSeatKey(_section, _row, _seat)
        );
        if (ticketPrice != 0) {
            return ticketPrice;
        }

        ticketPrice = getReservedSectionTicketPrice(buildRowKey(_section, _row));
        if (ticketPrice != 0) {
            return ticketPrice;
        }

        ticketPrice = getReservedSectionTicketPrice(_section);
        if (ticketPrice != 0) {
            return ticketPrice;
        }

        return defaultTicketPrice;
    }

    // admin functions
    function setEventDateTime(
        uint256 _eventDateTime
    ) external onlyAdmin notFinalized resetSignatures {
        eventDateTime = _eventDateTime;
    }

    function setDefaultTicketPrice(
        uint256 _ticketPrice
    ) external onlyAdmin notFinalized resetSignatures {
        defaultTicketPrice = normalizeTicketPrice(_ticketPrice);
    }

    function setOpenSection(
        string calldata _key,
        uint256 _ticketPrice,
        uint256 _capacity
    ) external onlyAdmin notFinalized resetSignatures {
        OpenSection memory openSection;
        openSection.ticketPrice = normalizeTicketPrice(_ticketPrice);
        openSection.maxCapacity = _capacity;
        openSection.remainingCapacity = _capacity;
        openSections.set(_key, openSection);
    }

    function setReservedSection(
        string calldata _key,
        uint256 _ticketPrice
    ) external onlyAdmin notFinalized resetSignatures {
        ReservedSection memory reservedSection;
        reservedSection.ticketPrice = normalizeTicketPrice(_ticketPrice);
        reservedSections.set(_key, reservedSection);
    }

    function venueSign() external onlyVenue notFinalized readyToSign {
        venueSigned = true;
    }

    function entertainerSign()
        external
        onlyEntertainer
        notFinalized
        readyToSign
    {
        entertainerSigned = true;
    }

    function enableTicketSales() external onlyAdmin finalized tokenCreated {
        ticketSalesEnabled = true;
    }

    function disableTicketSales() external onlyAdmin finalized salesEnabled {
        ticketSalesEnabled = false;
    }

    function createNft(
        string memory name,
        string memory symbol,
        string memory memo,
        int64 maxSupply,
        int64 autoRenewPeriod
    ) external payable onlyEntertainer finalized returns (address) {
        IHederaTokenService.TokenKey[]
            memory keys = new IHederaTokenService.TokenKey[](1);
        keys[0] = getSingleKey(
            KeyType.SUPPLY,
            KeyValueType.CONTRACT_ID,
            address(this)
        );

        IHederaTokenService.HederaToken memory token;
        token.name = name;
        token.symbol = symbol;
        token.memo = memo;
        token.treasury = address(this);
        token.tokenSupplyType = true; // FINITE
        token.maxSupply = maxSupply;
        token.tokenKeys = keys;
        token.freezeDefault = false;
        token.expiry = createAutoRenewExpiry(address(this), autoRenewPeriod);

        (int256 responseCode, address createdToken) = HederaTokenService
            .createNonFungibleToken(token);

        require(
            responseCode == HederaResponseCodes.SUCCESS,
            "Failed to create NFT collection"
        );
        tokenAddress = createdToken;
        return createdToken;
    }

    function mintNft(
        string calldata _section,
        string calldata _row,
        string calldata _seat,
        bytes[] memory metadata
    ) external payable onlyOwner finalized salesEnabled returns (int64) {
        int256 ticketPrice = getSeatTicketPrice(_section, _row, _seat);
        require(ticketPrice <= 0 || uint256(ticketPrice) <= msg.value, "Insufficient payment amount");
        require(isSeatAvailable(_section, _row, _seat), "Ticket not available");

        (int256 response, , int64[] memory serials) = HederaTokenService
            .mintToken(tokenAddress, 0, metadata);

        require(
            response == HederaResponseCodes.SUCCESS,
            "Failed to mint NFTicket"
        );

        int64 serial = serials[0];
        OpenSection memory openSection = openSections.get(_section);
        string memory seatKey = buildSeatKey(_section, _row, _seat);
        ReservedSeat memory reservedSeat = reservedSeats.get(seatKey);
        if (openSection.maxCapacity > 0) {
          openSection.remainingCapacity--;
        } else {
          reservedSeat.serial = serial;
          reservedSeats.set(seatKey, reservedSeat);
        }

        return serial;
    }

    function transferNft(
        address token,
        address receiver,
        int64 serial
    ) external onlyOwner finalized salesEnabled returns (int256) {
        HederaTokenService.associateToken(receiver, token);
        int256 response = HederaTokenService.transferNFT(
            token,
            address(this),
            receiver,
            serial
        );

        require(
            response == HederaResponseCodes.SUCCESS,
            "Failed to transfer NFTicket"
        );

        return response;
    }

    // internal functions
    function buildSeatKey(
        string calldata _section,
        string calldata _row,
        string calldata _seat
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(_section, ":", _row, ":", _seat));
    }

    function buildRowKey(
        string calldata _section,
        string calldata _row
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(_section, ":", _row));
    }

    function normalizeTicketPrice(uint256 _ticketPrice) internal pure returns (int256) {
        // We need to differentiate between an unset ticket price and a free ticket
        // and since unset values are always 0, we'll use -1 to represent free tickets
        return (_ticketPrice == 0 ? -1 : int(_ticketPrice));
    }

    function getOpenSectionTicketPrice(
        string memory _openSectionKey
    ) internal view returns (int256) {
        return openSections.get(_openSectionKey).ticketPrice;
    }

    function getReservedSectionTicketPrice(
        string memory _reservedSectionKey
    ) internal view returns (int256) {
        return reservedSections.get(_reservedSectionKey).ticketPrice;
    }
}
