// SPDX-License-Identifier: MIT 

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SRDNFT is ERC721URIStorage, Ownable {

	uint256 public counter;

    uint256 private randNum = 0;

    mapping(uint256 => uint256) public tokenIdToTypes;

    mapping(address => uint256[]) public userNFTIDs;

    mapping(uint256 => uint256) public tokenIdToIndex;

    mapping(address => mapping(uint256 => uint256)) public userNFTTypeNumber;

    mapping(address => mapping(uint256 => uint256)) public userNFTBuyNumber;

    mapping(uint256 => uint256) public typeNumber;

    mapping(uint256 => uint256) public tokenIdToStatus;

    mapping(uint256 => uint256) public tokenIdToCreatTime;

    mapping(uint256 => uint256) public tokenIdToDrawTime;

    mapping(uint256 => uint256) public tokenIdToDrawTimes;

    mapping(uint256 => uint256) public tokenIdToProfit;

    mapping(uint256 => uint256) public typeToDrawTimesLimit;

    mapping(uint256 => string) public typeToName;

    mapping(uint256 => string) public typeToSymbol;

    mapping(uint256 => uint256) public typeToPrices;

    mapping(uint256 => uint256) public typeToAmount;

    mapping(uint256 => uint256) public typeToDrawTime;

    mapping(uint256 => uint256) public typeToOnceProfit;

    mapping(uint256 => uint256) public typeToNPY;
    
    mapping(address => bool) public isController;

    uint256 public perNFTBuyLimit;

    
	constructor() ERC721("SpaceRobotDaoNFT", "SRDN"){
		counter = 0;

        typeToName[1] = "Phantom Robot";
        typeToName[2] = "Genesis Robot";

        typeToSymbol[1] = "PR";
        typeToSymbol[2] = "GR";

        typeToPrices[1] = 2 * 10 ** 17;
        typeToPrices[2] = 5 * 10 ** 17;

        typeToAmount[1] = 2500;
        typeToAmount[2] = 800;

        typeToDrawTimesLimit[1] = 30;
        typeToDrawTimesLimit[2] = 50;

        typeToDrawTime[1] = 15 days;
        typeToDrawTime[2] = 7 days;

        typeToOnceProfit[1] = 1 * 10 ** 17;
        typeToOnceProfit[2] = 2 * 10 ** 17;

        typeToNPY[1] = 1500;
        typeToNPY[2] = 2000;

        perNFTBuyLimit = 2;
	}

    function addController(address controllerAddr) public onlyOwner {
        isController[controllerAddr] = true;
    }

    function removeController(address controllerAddr) public onlyOwner {
        isController[controllerAddr] = false;
    }

    modifier onlyController {
        require(isController[msg.sender],"Must be controller");
        _;
    }

    function setNFTPrice(uint256 types, uint256 price) public onlyOwner{
        typeToPrices[types] = price;
    }

    function setNFTAmount(uint256 types, uint256 amount) public onlyOwner {
        typeToAmount[types] = amount;
    }

    function setNFTDrawTimesLimit(uint256 types, uint256 limit) public onlyOwner {
        typeToDrawTimesLimit[types] = limit;
    }

    function setNFTDrawTime(uint256 types, uint256 time) public onlyOwner {
        typeToDrawTime[types] = time;
    }

    function setNFTProfit(uint256 types, uint256 profit) public onlyOwner {
        typeToOnceProfit[types] = profit;
    }

    function setNFTNPY(uint256 types, uint256 profit) public onlyOwner {
        typeToNPY[types] = profit;
    }

    function setNFTBuyLimit(uint256 limit) public onlyOwner {
        perNFTBuyLimit = limit;
    }

    function setMyNFTDrawTime(uint256 tokenId, uint256 time) public onlyController returns (bool) {
        tokenIdToDrawTime[tokenId] = time;

        return true;
    }

    function addMyNFTDrawTimes(uint256 tokenId, uint256 times) public onlyController returns (bool) {
        tokenIdToDrawTimes[tokenId] += times;

        return true;
    }

    function addMyNFTProfit(uint256 tokenId, uint256 profit) public onlyController returns (bool) {
        tokenIdToProfit[tokenId] += profit;

        return true;
    }

    function setMyNFTStatus(uint256 tokenId, uint256 status) public onlyController returns (bool) {
        if(tokenIdToStatus[tokenId] == status){
            return false;
        }

        tokenIdToStatus[tokenId] = status;

        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        require(tokenIdToStatus[tokenId] == 0, "ERC721: the NFT is unavailable");
        require(from != to, "ERC721: You can't send the NFT to yourself");

        uint256 index = tokenIdToIndex[tokenId];

        userNFTIDs[from][index] = 0;

        tokenIdToIndex[tokenId] = userNFTIDs[to].length;

        userNFTIDs[to].push(tokenId);

        userNFTTypeNumber[from][tokenIdToTypes[tokenId]] -= 1;

        userNFTTypeNumber[to][tokenIdToTypes[tokenId]] += 1;

        tokenIdToDrawTime[tokenId] =  block.timestamp;
        
        return super._transfer(from, to, tokenId);
    }

    function createNFT(address user, uint256 NFTType) public onlyController returns (uint256){
        require(typeToAmount[NFTType] > 0, "ERC721: out of stock");

        require(userNFTBuyNumber[user][NFTType] < perNFTBuyLimit, "ERC721: exceed the purchase limit");

        typeToAmount[NFTType] = typeToAmount[NFTType] - 1;

        counter ++;

        uint256 tokenId = counter;

        _safeMint(user, counter);

        typeNumber[NFTType] ++;

        tokenIdToTypes[tokenId] = NFTType;

        tokenIdToIndex[tokenId] = userNFTIDs[user].length;

        userNFTIDs[user].push(tokenId);

        userNFTTypeNumber[user][NFTType] ++;

        userNFTBuyNumber[user][NFTType] ++;

        tokenIdToCreatTime[tokenId] =  block.timestamp;

        tokenIdToDrawTime[tokenId] =  block.timestamp;
		
        return tokenId;
	} 

    function createNFTs(address[] memory users, uint256 NFTType) public onlyController {

        for(uint256 i = 0; i < users.length; i++){
            createNFT(users[i],NFTType);
        }
	}

	function burn(uint256 tokenId) public virtual {
		require(_isApprovedOrOwner(msg.sender, tokenId),"ERC721: you are not the owner nor approved!");

		super._burn(tokenId);

        uint256 index = tokenIdToIndex[tokenId];

        userNFTIDs[msg.sender][index] = 0;

        userNFTTypeNumber[msg.sender][tokenIdToTypes[tokenId]] -= 1;

        typeNumber[tokenIdToTypes[tokenId]] -= 1;

        tokenIdToCreatTime[tokenId] = 0;

        tokenIdToDrawTime[tokenId] = 0;
	}

    function approveToController(address ownerAddr, uint256 tokenId) public onlyController {
        address owner = ownerOf(tokenId);

        require(ownerAddr == owner, "ERC721: this user does not own this tokenId");

        _approve(msg.sender, tokenId);
    }

    function getUserNFTIDs(address user) public view returns(uint256[] memory ids) {

		ids = userNFTIDs[user];

        return ids;
	}

    function queryUserNFTIDs(address user) public view returns(uint256[] memory ids) {

		uint256[] memory ids0 = userNFTIDs[user];

        uint256[] memory ids1 = new uint256[](uint256(ids0.length));

        uint256 count;

        uint256 i;

        for(i = 0; i < ids0.length; i++){
            if(ids0[i] != 0){

                ids1[count] = ids0[i];

                count++;
            }
        }

        ids = new uint256[](uint256(count));

        for(i = 0; i < count; i++){
            ids[i] = ids1[i];
        }

        return ids;
	}

    function queryUserNFTIDsByType(address user, uint256 types) public view returns(uint256[] memory ids) {

		uint256[] memory ids0 = queryUserNFTIDs(user);

        uint256[] memory ids1 = new uint256[](uint256(ids0.length));

        uint256 count;

        uint256 i;

        for(i = 0; i < ids0.length; i++){
            if(tokenIdToTypes[ids0[i]] == types){

                ids1[count] = ids0[i];

                count++;
            }
        }

        ids = new uint256[](uint256(count));

        for(i = 0; i < count; i++){
            ids[i] = ids1[i];
        }

        return ids;
	}

    function queryNFTDetail(uint256 types) public view returns(string memory name, string memory symbol, 
    uint256 drawTime, uint256 timesLimit, uint256 profit, uint256 NPY, uint256 amount, uint256 price) {

        name = typeToName[types];
        symbol = typeToSymbol[types];
        drawTime = typeToDrawTime[types] / 1 days;
        timesLimit = typeToDrawTimesLimit[types];
        profit = typeToOnceProfit[types] / (10 ** 14);
        NPY = typeToNPY[types];
        amount = typeToAmount[types];
        price = typeToPrices[types] / (10 ** 14);
	}

}