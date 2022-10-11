// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./SRDNFT.sol";

interface ISwapRouter {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
}

contract SRDQuery is Ownable {

    using SafeMath for uint256;

    ISwapRouter public _swapRouter;

    address public pair;

    address public usdtPair;

    address public SRDAddr;
    address public USDTAddr;
    address public SRDNAddr;

    ERC20 public SRD;
    ERC20 public USDT;
    SRDNFT public SRDN;

    constructor() {

        SRDAddr = address(0x4A24EDda87797Fe0Ac6dfB6f3c40D60753d29cD9);
        USDTAddr = address(0x55d398326f99059fF775485246999027B3197955);
        SRDNAddr = address(0xbfF031B09588e81087CA06186D636955e967d832);

        SRD = ERC20(SRDAddr);

        USDT = ERC20(USDTAddr);

        SRDN = SRDNFT(SRDNAddr);

        pair = address(0x1F3A879cb0140b42F77266197ED62458388b46bA);

        usdtPair = address(0x20bCC3b8a0091dDac2d0BC30F68E6CBb97de59Cd);

        _swapRouter = ISwapRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    }

    function setSRD(address _SRDAddr) public onlyOwner {
        SRDAddr = _SRDAddr;
        SRD = ERC20(_SRDAddr);
    }

    function setUSDT(address _USDTAddr) public onlyOwner {
        USDTAddr = _USDTAddr;
        USDT = ERC20(_USDTAddr);
    }

    function setSRDN(address _SRDNAddr) public onlyOwner {
        SRDNAddr = _SRDNAddr;
        SRDN = SRDNFT(_SRDNAddr);
    }

    function setPair(address _pair) public onlyOwner {
        pair = address(_pair);
    }

    function setUsdtPair(address _pair) public onlyOwner {
        usdtPair = address(_pair);
    }

    function queryNFTProfitAndTimes(uint256 tokenId) public view returns(uint256 profit, uint256 times){

        uint256 drawTimes = SRDN.tokenIdToDrawTimes(tokenId);

        uint256 types = SRDN.tokenIdToTypes(tokenId);

        uint256 drawTime = SRDN.tokenIdToDrawTime(tokenId);

        if(drawTimes < SRDN.typeToDrawTimesLimit(types)){

            times = (block.timestamp - drawTime).div(SRDN.typeToDrawTime(types));

            if(drawTimes + times > SRDN.typeToDrawTimesLimit(types)){
                times = SRDN.typeToDrawTimesLimit(types) - drawTimes;
            }

            profit = bnbEqualsToToken(SRDN.typeToOnceProfit(types).mul(times));
        }

        return (profit, times);
    }

    function queryNFTProfit(address user) public view returns(uint256 profit) {
        uint256[] memory tokenIds = SRDN.queryUserNFTIDs(user);

        uint256 types;
        uint256 profit0;
        uint256 i;

        for(i = 0; i < tokenIds.length; i++){

            types = SRDN.tokenIdToTypes(tokenIds[i]);

            if(SRDN.ownerOf(tokenIds[i]) == user && SRDN.tokenIdToDrawTimes(tokenIds[i]) < SRDN.typeToDrawTimesLimit(types)){
                (profit0,) = queryNFTProfitAndTimes(tokenIds[i]);

                profit += profit0;
            }
        }

        return profit;
    }

    function bnbEqualsToToken(uint256 bnbAmount) public view returns(uint256 tokenAmount) {
        
        uint256 tokenOfPair = SRD.balanceOf(pair);

        uint256 bnbOfPair = ERC20(_swapRouter.WETH()).balanceOf(pair);

        if(tokenOfPair > 0 && bnbOfPair > 0){
            tokenAmount = bnbAmount.mul(tokenOfPair).div(bnbOfPair);
        }

        return tokenAmount;
    }

    function bnbEqualsToUsdt(uint256 bnbAmount) public view returns(uint256 tokenAmount) {
        
        uint256 tokenOfPair = ERC20(USDT).balanceOf(usdtPair);

        uint256 bnbOfPair = ERC20(_swapRouter.WETH()).balanceOf(usdtPair);

        if(tokenOfPair > 0 && bnbOfPair > 0){
            tokenAmount = bnbAmount.mul(tokenOfPair).div(bnbOfPair);
        }

        return tokenAmount;
    }

    function tokenEqualsToBnb(uint256 tokenAmount) public view returns(uint256 bnbAmount) {
        
        uint256 tokenOfPair = SRD.balanceOf(pair);

        uint256 bnbOfPair = ERC20(_swapRouter.WETH()).balanceOf(pair);

        if(tokenOfPair > 0 && bnbOfPair > 0){
            bnbAmount = tokenAmount.mul(bnbOfPair).div(tokenOfPair);
        }

        return bnbAmount;
    }

    function toString(address account) public pure returns (string memory) {
        return toString(abi.encodePacked(account));
    }

    function toString(bytes memory data) public pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint i = 0; i < data.length; i++) {
            str[2 + i * 2] = alphabet[uint(uint8(data[i] >> 4))];
            str[3 + i * 2] = alphabet[uint(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }

}