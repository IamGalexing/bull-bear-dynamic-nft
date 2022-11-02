// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract BullBear is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    KeeperCompatibleInterface,
    Ownable,
    VRFConsumerBaseV2
{
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    AggregatorV3Interface public s_pricefeed;

    VRFCoordinatorV2Interface public COORDINATOR;
    uint256[] public s_randomWords;
    uint256 public s_requestId;
    uint32 public callbackGasLimit = 500000;
    uint64 public s_subscriptionId;
    bytes32 s_keyhash =
        0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;

    uint public s_interval;
    uint public s_lastTimeStamp;
    int256 public s_currentPrice;

    enum MarketTrend {
        BULL,
        BEAR
    }
    MarketTrend public s_currentMarketTrend = MarketTrend.BULL;

    string[] s_bullUrisIpfs = [
        "https://ipfs.io/ipfs/QmRXyfi3oNZCubDxiVFre3kLZ8XeGt6pQsnAQRZ7akhSNs?filename=gamer_bull.json",
        "https://ipfs.io/ipfs/QmRJVFeMrtYS2CUVUM2cHJpBV5aX2xurpnsfZxLTTQbiD3?filename=party_bull.json",
        "https://ipfs.io/ipfs/QmdcURmN1kEEtKgnbkVJJ8hrmsSWHpZvLkRgsKKoiWvW9g?filename=simple_bull.json"
    ];
    string[] s_bearUrisIpfs = [
        "https://ipfs.io/ipfs/Qmdx9Hx7FCDZGExyjLR6vYcnutUR8KhBZBnZfAPHiUommN?filename=beanie_bear.json",
        "https://ipfs.io/ipfs/QmTVLyTSuiKGUEmb88BgXG3qNC8YgpHZiFbjHrXKH3QHEu?filename=coolio_bear.json",
        "https://ipfs.io/ipfs/QmbKhBXVWmwrYsTPFYfroR2N7NAekAMxHUVg2CWks7i9qj?filename=simple_bear.json"
    ];

    event TokensUpdated(string marketTrend);

    constructor(
        uint _interval,
        address _vrfCoordinator,
        address _pricefeed
    ) ERC721("Bull&Bear", "BBTK") VRFConsumerBaseV2(_vrfCoordinator) {
        s_interval = _interval;
        s_lastTimeStamp = block.timestamp;
        s_pricefeed = AggregatorV3Interface(_pricefeed);
        s_currentPrice = getLatestPrice();
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
    }

    function safeMint(address to) public {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        string memory defaultUri = s_bullUrisIpfs[0];
        _setTokenURI(tokenId, defaultUri);
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (
            bool upkeepNeeded,
            bytes memory /*performData */
        )
    {
        upkeepNeeded = (block.timestamp - s_lastTimeStamp) > s_interval;
    }

    function performUpkeep(
        bytes calldata /* performData */
    ) external override {
        if ((block.timestamp - s_lastTimeStamp) > s_interval) {
            s_lastTimeStamp = block.timestamp;
            int latestPrice = getLatestPrice();

            if (latestPrice == s_currentPrice) {
                return;
            }

            if (latestPrice < s_currentPrice) {
                s_currentMarketTrend = MarketTrend.BEAR;
            } else {
                s_currentMarketTrend = MarketTrend.BULL;
            }

            requestRandomnessForNFTUris();
            s_currentPrice = latestPrice;
        } else {
            return;
        }
    }

    function getLatestPrice() public view returns (int256) {
        (, int price, , , ) = s_pricefeed.latestRoundData();
        return price;
    }

    function requestRandomnessForNFTUris() internal {
        require(s_subscriptionId != 0, "Subscription ID not set");
        s_requestId = COORDINATOR.requestRandomWords(
            s_keyhash,
            s_subscriptionId,
            3,
            callbackGasLimit,
            1
        );
    }

    function fulfillRandomWords(uint256, uint256[] memory _randomWords)
        internal
        override
    {
        s_randomWords = _randomWords;

        string[] memory urisForTrend = s_currentMarketTrend == MarketTrend.BULL
            ? s_bullUrisIpfs
            : s_bearUrisIpfs;
        uint256 idx = _randomWords[0] % urisForTrend.length;

        for (uint i = 0; i < _tokenIdCounter.current(); i++) {
            _setTokenURI(i, urisForTrend[idx]);
        }

        string memory trend = s_currentMarketTrend == MarketTrend.BULL
            ? "bullish"
            : "bearish";

        emit TokensUpdated(trend);
    }

    // setters

    function setPriceFeed(address _newFeed) public onlyOwner {
        s_pricefeed = AggregatorV3Interface(_newFeed);
    }

    function setInterval(uint256 _interval) public onlyOwner {
        s_interval = _interval;
    }

    function setSubscriptionId(uint64 _id) public onlyOwner {
        s_subscriptionId = _id;
    }

    function setCallbackGasLimit(uint32 _maxGas) public onlyOwner {
        callbackGasLimit = _maxGas;
    }

    function setVrfCoodinator(address _address) public onlyOwner {
        COORDINATOR = VRFCoordinatorV2Interface(_address);
    }

    function setKeyHash(bytes32 _keyHash) public onlyOwner {
        s_keyhash = _keyHash;
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
