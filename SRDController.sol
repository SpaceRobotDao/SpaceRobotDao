// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./SRDQuery.sol";

contract SRDController is Ownable {

    using SafeMath for uint256;

    event PaymentReceived(address from, uint256 amount);
    event BuyNFT(address account, uint256 nftType, uint256 bnbAmount, uint256 tokenId);
    event DrawNFTProfit(address account, uint256 tokenId, uint256 nftType, uint256 profit);
    event DrawNFTProfits(address account, uint256 profit);
    event DrawNodeProfit(address account, uint256 nodeId, uint256 profit);
    event OpenNode(address account, uint256 tokenCost);
    event BindRecommender(address from, address recommender);

    address public receiveAddress;

    address public deadWallet = 0x000000000000000000000000000000000000dEaD;

    mapping(address => address[]) public invitees;

    mapping(address => address) public myRecommender;

    mapping(address => uint256) public bindTime;

    mapping(address => uint256) public userNFTProfits;

    mapping(uint256 => uint256) public nodeProfitRates;

    mapping(address => uint256) public nodeIDs;

    mapping(uint256 => address) public nodeIDToAddress;

    mapping(uint256 => uint256) public nodeOpenTime;

    mapping(uint256 => uint256) public nodeIDToProfits;

    mapping(uint256 => uint256) public drawNodeProfits;

    mapping(uint256 => uint256) public typeToBnbBuyBackAmount;

    mapping(uint256 => uint256) public typeToTokenBurnAmount;

    mapping(uint256 => uint256) public typeToNFTProfits;

    uint256 public nodeToNFTAward;

    uint256 public nodeID;

    uint256 public openNodeBnbLimit;
    uint256 public openNodeTokenLimit;

    string public baseLink;

    bool private inSwap;

    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    ISwapRouter public _swapRouter;

    ERC20 SRD;
    ERC20 USDT;
    SRDNFT SRDN;
    SRDQuery SRDQ;

    constructor() {

        SRDQ = SRDQuery(0xdB1D8B36b21285CdBBf76ba797EA2380dD7AD788);

        _swapRouter = ISwapRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);

        receiveAddress = address(0x3F1d52875e15701C1F317a5526E6cae820188E35);

        SRD = SRDQ.SRD();
        USDT = SRDQ.USDT();
        SRDN = SRDQ.SRDN();

        openNodeBnbLimit = 1 * 10 ** 17;

        openNodeTokenLimit = 300 * 10 ** 18;

        nodeProfitRates[1] = 600;
        nodeProfitRates[2] = 300;
        nodeProfitRates[3] = 100;
    }

    receive() external payable virtual {
        emit PaymentReceived(_msgSender(), msg.value);
    }

    function setBaseLink(string memory base) public onlyOwner {
        baseLink = base;
    }

    function setSRDQ(address _SRDQ) public onlyOwner {
        SRDQ = SRDQuery(_SRDQ);
    }

    function updateSRD() public onlyOwner {
        SRD = SRDQ.SRD();
    }

    function updateUSDT() public onlyOwner {
        USDT = SRDQ.USDT();
    }

    function updateSRDN() public onlyOwner {
        SRDN = SRDQ.SRDN();
    }

    function setNodeProfitRate(uint256 nodeIndex, uint256 rate) public onlyOwner {
        nodeProfitRates[nodeIndex] = rate;
    }

    function setOpenNodeBnbLimit(uint256 _bnbLimit) public onlyOwner {
        openNodeBnbLimit = _bnbLimit;
    }

    function setOpenNodeTokenLimit(uint256 _tokenLimit) public onlyOwner {
        openNodeTokenLimit = _tokenLimit;
    }

    function setReceiveAddress(address _receiveAddress) public onlyOwner {
        receiveAddress = address(_receiveAddress);
    }

    function withdraw(uint256 amount) public onlyOwner {
        payable(msg.sender).transfer(amount);
    }

    function buyNFT(uint256 types) public payable lockTheSwap returns(uint256 tokenId) {

        require(msg.value == SRDN.typeToPrices(types), "Wrong input");

        payable(address(this)).transfer(msg.value);

        tokenId = SRDN.createNFT(msg.sender, types);

        address[] memory path = new address[](2);
        path[0] = _swapRouter.WETH();
        path[1] = address(SRD);

        uint256 initialBalance = SRD.balanceOf(address(this));

        _swapRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{value : msg.value}(
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );

        uint256 burnBalance = SRD.balanceOf(address(this)) - initialBalance;
        
        typeToBnbBuyBackAmount[types] += msg.value;
        typeToTokenBurnAmount[types] += burnBalance;

        SRD.transfer(deadWallet, burnBalance);

        emit BuyNFT(msg.sender, types, msg.value, tokenId);

        return tokenId;
    }

    function openNode() public {

        require(nodeIDs[msg.sender] == 0, "You have opened the node");

        uint256 tokenAmount;

        if(SRD.balanceOf(SRDQ.pair()) == 0 && ERC20(_swapRouter.WETH()).balanceOf(SRDQ.pair()) == 0){
            require(msg.sender.balance >= openNodeBnbLimit, "You don't have enough bnb");
        }else{
            require(SRD.balanceOf(msg.sender) >= openNodeTokenLimit, "You don't have enough SRD");
            SRD.transferFrom(msg.sender, receiveAddress, openNodeTokenLimit);
            tokenAmount = openNodeTokenLimit;
        }

        nodeID++;

        nodeIDs[msg.sender] = nodeID;

        nodeIDToAddress[nodeID] = msg.sender;

        nodeOpenTime[nodeID] = block.timestamp;

        emit OpenNode(msg.sender, tokenAmount);
    }

    function drawNFTProfits() public {

        uint256[] memory tokenIds = SRDN.queryUserNFTIDs(msg.sender);

        uint256 i;
        uint256 types;
        uint256 profit0;
        uint256 profit;
        uint256 drawTimes;

        for(i = 0; i < tokenIds.length; i++){
            require(SRDN.ownerOf(tokenIds[i]) == msg.sender, "You are not the owner");

            types = SRDN.tokenIdToTypes(tokenIds[i]);

            if(SRDN.tokenIdToDrawTimes(tokenIds[i]) < SRDN.typeToDrawTimesLimit(types)){
                (profit0, drawTimes) = SRDQ.queryNFTProfitAndTimes(tokenIds[i]);

                profit += profit0;

                typeToNFTProfits[types] += profit0;

                SRDN.addMyNFTProfit(tokenIds[i], profit0);

                SRDN.addMyNFTDrawTimes(tokenIds[i], drawTimes);

                SRDN.setMyNFTDrawTime(tokenIds[i], SRDN.tokenIdToDrawTime(tokenIds[i]) + drawTimes.mul(SRDN.typeToDrawTime(types)));
            }
        }

        userNFTProfits[msg.sender] += profit;

        if(profit > 0){
            SRD.transfer(msg.sender, profit);

            address user = msg.sender;

            uint256 nodeProfit;

            for(i = 1; i < 4; i++){
                if(myRecommender[user] != address(0)){
                    nodeProfit = profit.mul(nodeProfitRates[i]).div(10000);
                    user = myRecommender[user];
                    nodeIDToProfits[nodeIDs[user]] += nodeProfit;
                    nodeToNFTAward += nodeProfit;
                }else{
                    break;
                }
            }
        }

        emit DrawNFTProfits(msg.sender, profit);
    }

    function drawNFTProfit(uint256 tokenId) public {

        require(SRDN.ownerOf(tokenId) == msg.sender, "You are not the owner");

        uint256 types = SRDN.tokenIdToTypes(tokenId);

        require(SRDN.tokenIdToDrawTimes(tokenId) < SRDN.typeToDrawTimesLimit(types), "The number of rewards has reached the upper limit");

        (uint256 profit,uint256 drawTimes) = SRDQ.queryNFTProfitAndTimes(tokenId);

        SRDN.addMyNFTDrawTimes(tokenId, drawTimes);

        SRDN.setMyNFTDrawTime(tokenId, SRDN.tokenIdToDrawTime(tokenId) + drawTimes.mul(SRDN.typeToDrawTime(types)));

        if(profit > 0){
            SRD.transfer(msg.sender, profit);

            typeToNFTProfits[types] += profit;

            userNFTProfits[msg.sender] += profit;

            SRDN.addMyNFTProfit(tokenId, profit);

            SRDN.addMyNFTDrawTimes(tokenId, drawTimes);

            SRDN.setMyNFTDrawTime(tokenId, SRDN.tokenIdToDrawTime(tokenId) + drawTimes.mul(SRDN.typeToDrawTime(types)));

            address user = msg.sender;

            uint256 nodeProfit;

            uint256 i;

            for(i = 1; i < 4; i++){
                if(myRecommender[user] != address(0)){
                    nodeProfit = profit.mul(nodeProfitRates[i]).div(10000);
                    
                    user = myRecommender[user];

                    nodeIDToProfits[nodeIDs[user]] += nodeProfit;

                    nodeToNFTAward += nodeProfit;
                }else{
                    break;
                }
            }
        }

        emit DrawNFTProfit(msg.sender, tokenId, types, profit);
    }

    function drawNodeProfit() public {

        uint256 usernodeID = nodeIDs[msg.sender];

        uint256 profit = nodeIDToProfits[usernodeID] - drawNodeProfits[usernodeID];

        require(profit > 0, "You have no profit to withdraw");

        SRD.transfer(msg.sender, profit);

        drawNodeProfits[usernodeID] += profit;

        nodeToNFTAward += profit;

        emit DrawNodeProfit(msg.sender, usernodeID, profit);
    }

    function bindRecommender(address recommender) public {

        require(nodeIDs[recommender] > 0, "The recommender have not opened the node");

        require(myRecommender[msg.sender] == address(0), "You have bound a recommender");

        require(msg.sender != recommender, "You can't bind yourself");

        require(recommender != address(0) && recommender != deadWallet, "You can't bind address 0");

        myRecommender[msg.sender] = recommender;

        invitees[recommender].push(msg.sender);

        bindTime[msg.sender] = block.timestamp;

        emit BindRecommender(msg.sender, recommender);
    }       

    function queryNodeProfits(address user) public view returns(uint256 profit) {
        uint256 usernodeID = nodeIDs[user];
        profit = nodeIDToProfits[usernodeID] - drawNodeProfits[usernodeID];
    }

    function queryNodeProfit(address user) public view returns(uint256 nodeProfit, uint256 profit) {
        uint256 usernodeID = nodeIDs[user];
        nodeProfit = nodeIDToProfits[usernodeID].div(10 ** 14);
        profit = (nodeIDToProfits[usernodeID] - drawNodeProfits[usernodeID]).div(10 ** 14);
    }

    function queryNodeInviteeAmount(address user, uint256 nodeType) public view returns(uint256 amount) {

        uint256 amount0 = invitees[user].length;

        if(nodeType == 1){
            amount = amount0;
        }
        
        if(nodeType == 2){
            uint256 i;

            for(i = 0; i < amount0; i++){
                amount += invitees[invitees[user][i]].length;
            }
        }

        if(nodeType == 3){
            uint256 i;
            uint256 j;
            uint256 end;
            address user0;

            for(i = 0; i < amount0; i++){
                user0 = invitees[user][i];
                end = invitees[user0].length;

                for(j = 0; j < end; j++){
                    amount += invitees[invitees[user0][j]].length;
                }
            }
        }

        return amount;
    }

    function queryNodeInviteeAmounts(address user) public view returns(uint256 node1Amount, uint256 node2Amount, uint256 node3Amount) {

        node1Amount = queryNodeInviteeAmount(user, 1);
        node2Amount = queryNodeInviteeAmount(user, 2);
        node3Amount = queryNodeInviteeAmount(user, 3);

        return (node1Amount, node2Amount, node3Amount);
    }

    function queryNodeInviteeDetail(address user, uint256 nodeType) public view returns(uint256[] memory bindTimes, 
    uint256[] memory nodeIds, address[] memory users) {

        users = queryNodeInvitee(user, nodeType);

        bindTimes = new uint256[](uint256(users.length));
        nodeIds = new uint256[](uint256(users.length));

        uint256 i;

        for(i = 0; i < users.length; i++){
            bindTimes[i] = bindTime[users[i]];
            nodeIds[i] = nodeIDs[users[i]];
        }

        return (bindTimes, nodeIds, users);
    }

    function queryNodeInvitee(address user, uint256 nodeType) public view returns(address[] memory users) {

        uint256 amount = queryNodeInviteeAmount(user, nodeType);

        users = new address[](uint256(amount));

        uint256 count;
        uint256 i;
        
        if(nodeType == 1){
            for(i = 0; i < invitees[user].length; i++){
                users[count] = invitees[user][i];
                count++;
            }
        }

        if(nodeType == 2){
            address user1;
            uint256 j;

            for(i = 0; i < invitees[user].length; i++){
                user1 = invitees[user][i];

                for(j = 0; j < invitees[user1].length; j++){
                    users[count] = invitees[user1][j];
                    count++;
                }
            }
        }

        address user2;

        if(nodeType == 3){
            address user1;
            uint256 j;
            uint256 k;

            for(i = 0; i < invitees[user].length; i++){
                user1 = invitees[user][i];

                for(j = 0; j < invitees[user1].length; j++){
                    user2 = invitees[user1][j];

                    for(k = 0; k < invitees[user2].length; k++){
                        users[count] = invitees[user2][k];
                        count++;
                    }
                }
            }
        }

        return users;
    }

    function queryNode1TokenIds(address user) public view returns(uint256[] memory tokenIds) {

        uint256 node1Amount = queryNodeInviteeAmount(user, 1);
    
        address[] memory users1 = new address[](uint256(node1Amount));
    
        uint256 i;
        uint256 j;
        uint256 count;
        uint256[] memory tokenIds0;
        uint256[] memory tokenIds1 = new uint256[](uint256(SRDN.counter()));

        for(i = 0; i < node1Amount; i++){
            users1[i] = invitees[user][i];

            tokenIds0 = SRDN.queryUserNFTIDs(users1[i]);

            for(j = 0; j < tokenIds0.length; j++){
                tokenIds1[count] = tokenIds0[j];
                count++;
            }
        }

        tokenIds = new uint256[](uint256(count));

        for(i = 0; i < count; i++){
            tokenIds[i] = tokenIds1[i];
        }

        return tokenIds;
    }

    function queryNodeTokenIds(address user) public view returns(uint256[] memory tokenIds) {

        uint256[] memory tokenIds0 = new uint256[](uint256(SRDN.counter()));

        uint256[] memory tokenIds1;

        uint256 count;
        uint256 i;
        uint256 j;

        tokenIds1 = queryNode1TokenIds(user);

        for(i = 0; i < tokenIds1.length; i++){
            tokenIds0[count] = tokenIds1[i];
            count++;
        }

        address[] memory users = queryNodeInvitee(user, 1);

        for(i = 0; i < users.length; i++){

            tokenIds1 = queryNode1TokenIds(users[i]);

            for(j = 0; j < tokenIds1.length; j++){
                tokenIds0[count] = tokenIds1[j];
                count++;
            }
        }

        users = queryNodeInvitee(user, 2);

        for(i = 0; i < users.length; i++){

            tokenIds1 = queryNode1TokenIds(users[i]);

            for(j = 0; j < tokenIds1.length; j++){
                tokenIds0[count] = tokenIds1[j];
                count++;
            }
        }

        tokenIds = new uint256[](uint256(count));

        for(i = 0; i < count; i++){
            tokenIds[i] = tokenIds0[i];
        }

        return tokenIds;
    }

    function queryNodeDetail(address user) public view returns(uint256[] memory buyTimes, uint256[] memory tokenIds, 
    uint256[] memory nodeIds, address[] memory users, uint256[] memory status) {

        tokenIds = queryNodeTokenIds(user);

        buyTimes = new uint256[](uint256(tokenIds.length));
        nodeIds = new uint256[](uint256(tokenIds.length));
        users = new address[](uint256(tokenIds.length));
        status = new uint256[](uint256(tokenIds.length));

        uint256 i;

        for(i = 0; i < tokenIds.length; i++){
            buyTimes[i] = SRDN.tokenIdToCreatTime(tokenIds[i]);
            users[i] = SRDN.ownerOf(tokenIds[i]);
            nodeIds[i] = nodeIDs[users[i]];
            status[i] = SRDN.tokenIdToStatus(tokenIds[i]);
        }

        return (buyTimes, tokenIds, nodeIds, users, status);
    }

    function queryMyData(address user) public view returns(uint256 nftAmount, uint256 prNftAmount, uint256 grNftAmount, uint256 unclaimedAmount, uint256 usdtAmount) {
        prNftAmount = SRDN.queryUserNFTIDsByType(user, 1).length;
        grNftAmount = SRDN.queryUserNFTIDsByType(user, 2).length;
        nftAmount = prNftAmount + grNftAmount;
        unclaimedAmount = SRDQ.queryNFTProfit(user).div(10 ** 14);
        usdtAmount = SRDQ.bnbEqualsToUsdt(SRDQ.tokenEqualsToBnb(SRDQ.queryNFTProfit(user))).div(10 ** 14);
    }

    function queryNFTPledgeDetail(uint256 tokenId) public view returns(address owner, uint256 startTime, uint256 periodLeft, 
    uint256 nextTime, uint256 pledgeNPY, uint256 bnbProfit, uint256 tokenProfit, uint256 tatus) {

        uint256 types = SRDN.tokenIdToTypes(tokenId);

        owner = SRDN.ownerOf(tokenId);
        startTime = SRDN.tokenIdToCreatTime(tokenId);

        periodLeft = SRDN.typeToDrawTimesLimit(types) - SRDN.tokenIdToDrawTimes(tokenId);
        nextTime = SRDN.tokenIdToDrawTime(tokenId) + SRDN.typeToDrawTime(types);

        if(block.timestamp >= nextTime){
            uint256 times = (block.timestamp - nextTime).div(SRDN.typeToDrawTime(types));
            if(periodLeft <= times){
                periodLeft = 0;
                nextTime = 0;
            }else{
                periodLeft = periodLeft - (times + 1);
                nextTime = nextTime + (times + 1).mul(SRDN.typeToDrawTime(types));
            }  
        }

        tokenProfit = SRDN.tokenIdToProfit(tokenId).div(10 ** 14);
        bnbProfit = SRDQ.tokenEqualsToBnb(tokenProfit);
        pledgeNPY = bnbProfit.mul(10 ** 16).div(SRDN.typeToPrices(types));
        tatus = SRDN.tokenIdToStatus(tokenId);
	}

    function queryNFTDetail(uint256 tokenId) public view returns(string memory name, string memory symbol, 
    uint256 drawTime, uint256 timesLimit, uint256 Profit, uint256 NPY, uint256 amount, uint256 price) {
        (name, symbol, drawTime, timesLimit, Profit, NPY, amount, price) = SRDN.queryNFTDetail(SRDN.tokenIdToTypes(tokenId));
	}

    function queryPoolData() public view returns(uint256 currentAmount, uint256 miningAmount, uint256 nftAmount) {
        currentAmount = SRD.balanceOf(address(this)).div(10 ** 14);
        miningAmount = (typeToNFTProfits[1] + typeToNFTProfits[2] + nodeToNFTAward).div(10 ** 14);
        nftAmount = SRDN.counter();
	}

    function queryMyNFTData(address user) public view returns(uint256 nftAmount, uint256 profit) {
        nftAmount = SRDN.queryUserNFTIDs(user).length;
        profit = (userNFTProfits[user] + SRDQ.queryNFTProfit(user)).div(10 ** 14);
    }

    function queryNFTDataByType(uint256 types) public view returns(uint256 amount, uint256 bnbBuyBackAmount, uint256 tokenBurnAmount, uint256 profit) {

        amount = SRDN.typeNumber(types);
        bnbBuyBackAmount = typeToBnbBuyBackAmount[types].div(10 ** 14);
        tokenBurnAmount = typeToTokenBurnAmount[types].div(10 ** 14);
        profit = typeToNFTProfits[types].div(10 ** 14);
	}

    function queryTokenPriceForUsdt() public view returns(uint256 tokenPrice) {
        tokenPrice = SRDQ.bnbEqualsToUsdt(SRDQ.tokenEqualsToBnb(10 ** 18)).div(10 ** 14);
	}

    function queryUserTokens(address user) public view returns(uint256 tokenAmount, uint256 bnbAmount) {
        tokenAmount = SRD.balanceOf(user).div(10 ** 14);
        bnbAmount = user.balance.div(10 ** 14);
	}

    function checkUserIsCanBuyNft(address user, uint256 types) public view returns(bool) {

        if(SRDN.userNFTBuyNumber(user, types) < SRDN.perNFTBuyLimit()){
            return true;
        }
        
        return false;
	}

    function queryInvitees(address user) public view returns(address[] memory myInvitees) {
        myInvitees = invitees[user];
    }

    function queryIsAddLiquidity() public view returns(bool) {
        if(SRD.balanceOf(SRDQ.pair()) == 0 && ERC20(SRDQ._swapRouter().WETH()).balanceOf(SRDQ.pair()) == 0){
            return false;
        }
        return true;
    }

    function queryIsBindRecommender(address user) public view returns (bool){

        if(myRecommender[user] == address(0)){
            return false;
        }
        return true;
    }

    function queryInviteLink(address user) public view returns (string memory inviteLink){

        if(nodeIDs[user] > 0){
            string memory addr = SRDQ.toString(user);

            if (user != address(0)) {
                inviteLink = string(abi.encodePacked(baseLink, addr));
            }
        }

        return inviteLink;
    }

}