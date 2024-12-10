// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

//定义错误事件
error CarbonTrader__NotOwner();
error CarbonTrader__ParamError();
error CarbonTrader__TransferFailed();

contract CarbonTrader {
    mapping (address => uint256) private s_addressToAllowance;
    mapping (address => uint256) private s_frozenAllowance;
    mapping (address => uint256) private s_auctionAmount;
    mapping (string => trade) private s_trade;

    //11、交易拍卖的结构体
    struct trade{
        //卖家地址
        address seller;
        //要拍卖的碳额度
        uint256 sellAmount;
        //开始时间
        uint256 startTimestamp;
        //结束时间
        uint256 endTimestamp;
        //最少起拍数量
        uint256 minimumBidAmount;
        //每个单位起拍价格
        uint256 initPriceOfUnit;
        //买家的押金
        mapping (address => uint256) deposits;
        //投标信息
        mapping (address => string) bidInfos;
        //投标信息解密密钥
        mapping (address => string) bidSecrets;


    }

    //  4、immutable表示不可更改的
    address private immutable i_owner;

    IERC20 private immutable i_usdtToken;

    //3、初始化加载一次,将i_owner设置为首次部署的地址
    constructor (address usdtTokenAddress){
        i_owner = msg.sender;
        i_usdtToken = IERC20(usdtTokenAddress);
    }

    //2、只有管理员才能执行对应的函数,不是的话就返回，是的话可以往下执行函数,先创建构造器i_owner
    modifier onlyOwner(){
        if(msg.sender != i_owner){
            revert CarbonTrader__NotOwner();
        }
        _;
    }

    //1、发放额度,为了解决public的权限问题，需要定义modify修饰器
    function issueAllowance(address user, uint256 amount) public onlyOwner {
        s_addressToAllowance[user] += amount;
    }

    //5、查询接口
    function getAllowance(address user) public view returns (uint256){
        return s_addressToAllowance[user];
    }

    //6、冻结碳信用，新建数据结构用于存储冻结信息
    function freezeAllowance(address user , uint256 freezedAmount) public onlyOwner{
        s_addressToAllowance[user] -= freezedAmount;
        s_frozenAllowance[user] += freezedAmount;
    }

    //7、解冻
    function unfreezeAllowance(address user , uint256 freezedAmount) public onlyOwner{
        s_addressToAllowance[user] += freezedAmount;
        s_frozenAllowance[user] -= freezedAmount;
    }

    //8、获取冻结的碳信用
    function getFrozenAllowance(address user) public view returns (uint256){
        return s_frozenAllowance[user];
    }

    //9、每年对碳信用进行清除
    function destroyAllowance(address user , uint256 destroyAmount) public onlyOwner{
         s_addressToAllowance[user] -= destroyAmount;
    }

    //10、销毁掉所有的碳信用额度
    function destroyAllAllowance(address user) public onlyOwner{
         s_addressToAllowance[user] = 0;
         s_frozenAllowance[user] = 0;
    }

    //12、发起交易
    function startTrade(
        string memory tradeID,
        uint256 amount,
        uint256 startTimestamp,
        uint256 endTimestamp,
        uint256 minimumBidAmount,
        uint256 initPriceOfUnit
    ) public {
        //入参校验
        if(
            amount <= 0||
            startTimestamp >= endTimestamp||
            minimumBidAmount <= 0 ||
            initPriceOfUnit <= 0 ||
            minimumBidAmount > amount
        ) revert CarbonTrader__ParamError();

        trade storage newTrade = s_trade[tradeID];
        newTrade.seller = msg.sender;
        newTrade.sellAmount = amount;
        newTrade.startTimestamp = startTimestamp;
        newTrade.endTimestamp = endTimestamp;
        newTrade.minimumBidAmount = minimumBidAmount;
        newTrade.initPriceOfUnit = initPriceOfUnit;

        s_addressToAllowance[msg.sender] -= amount;
        s_frozenAllowance[msg.sender] += amount;
    }

    //13、获取交易
    function getTrade(string memory tradeID) public view returns (address , uint256, uint256, uint256, uint256, uint256){
        trade storage curTrade = s_trade[tradeID];
        return (
            curTrade.seller,
            curTrade.sellAmount ,
            curTrade.startTimestamp ,
            curTrade.endTimestamp ,
            curTrade.minimumBidAmount ,
            curTrade.initPriceOfUnit 
        );  
    }

    //14、质押
    function deposit(string memory tradeID, uint256 amount, string memory info) public {
        trade storage curTrade = s_trade[tradeID];

        bool success = i_usdtToken.transferFrom(msg.sender, address(this), amount);
        if(!success) revert CarbonTrader__TransferFailed();

        curTrade.deposits[msg.sender] = amount;
        setBidInfo(tradeID, info);
    }

    function setBidInfo(string memory tradeID, string memory info) public {
        trade storage curTrade = s_trade[tradeID];
        curTrade.bidInfos[msg.sender] = info;
    }

    function getTradeDeposit(string memory tradeID) public view returns (uint256){
       
        return  s_trade[tradeID].deposits[msg.sender];
    }

    //15、退款
    function refundDeposit(string memory tradeID) public {
        trade storage curTrade = s_trade[tradeID];
        uint256 depositAmount = curTrade.deposits[msg.sender];
        curTrade.deposits[msg.sender] = 0;

        bool success = i_usdtToken.transfer(msg.sender, depositAmount);
        if(!success){
            curTrade.deposits[msg.sender] = depositAmount;
            revert CarbonTrader__TransferFailed();
        }
    }

    //16、解密
    function setBidSecret(string memory tradeID, string memory secret) public {
        trade storage curTrade = s_trade[tradeID];
        curTrade.bidSecrets[msg.sender] = secret;
    }

    //17、拿到info
    function getBidInfo(string memory tradeID) public view returns(string memory){
        trade storage curTrade = s_trade[tradeID];
        return curTrade.bidInfos[msg.sender];
    }

    //18、补充函数，
    function finalizeAuctionAndTransferCarbon(
        string memory tradeID,
        //当初拍卖的碳额度
        uint256 allowanceAmount,
        //需要补充的
        uint256 addtionalAmountToPay
    )public {
        //获取保证金
        uint256 depositAmount = s_trade[tradeID].deposits[msg.sender];
        s_trade[tradeID].deposits[msg.sender] = 0;

        //把保证金和新补的钱给卖家
        address seller = s_trade[tradeID].seller;
        s_auctionAmount[seller] += (depositAmount + addtionalAmountToPay);

        //扣除卖家碳额度
        s_frozenAllowance[seller] = 0;

        //增家买家碳额度
        s_addressToAllowance[msg.sender] += allowanceAmount;

        bool success = i_usdtToken.transferFrom(msg.sender, address(this), addtionalAmountToPay);
        if(!success) revert CarbonTrader__TransferFailed();
    }

    //19、卖家提现
    function withdrawAcutionAmount()public {
        uint256 auctionAmount = s_auctionAmount[msg.sender];
        s_auctionAmount[msg.sender] = 0;

        bool success = i_usdtToken.transfer(msg.sender, auctionAmount);
        if(!success){
            s_auctionAmount[msg.sender] = auctionAmount;
            revert CarbonTrader__TransferFailed();
        }
    }



    
}