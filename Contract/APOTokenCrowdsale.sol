pragma solidity ^0.4.18;

import "./APOToken.sol";
import "./SafeMath.sol";
import "./Ownable.sol";
import "./RefundVault.sol";
import "./TokenTimelock.sol";
import "./ERC20Basic.sol";
import "./Crowdsale.sol";

contract APOTokenCrowdsale is Ownable, Crowdsale  {

    // The token being sold
    APOToken public token = new APOToken();
    
    // Locked Tokens for 12 month
    TokenTimelock public teamTokens;
    TokenTimelock public reserveTokens;
    
    // Address where funds are collected
    address public wallet;
    
    // Address of ither wallets
    address public bountyWallet;
    
    address public privateWallet;
    
    // refund vault used to hold funds while crowdsale is running
    RefundVault public vault = new RefundVault(msg.sender);

    // How many token units a buyer gets per wei
    uint256 public rate = 15000;

    // ICO start time
    uint256 public startTime = 1524650400;
    
    // ICO end time
    uint256 public endTime = 1527069599;
    
    // Min Amount for Purchase
    uint256 public minAmount = 0.1 * 1 ether;
    
    // Soft Cap
    uint256 public softCap = 6000 * 1 ether;
    
    // Hard Cap
    uint256 public hardCap = 14000 * 1 ether;
    
    // Unlock Date
    uint256 public unlockTime = endTime + 1 years;
    
    // Discount
    uint256 public discountPeriod =  1 weeks;
         
    // Finished
    bool public isFinalized = false;

    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
    event Finalized();

    modifier onlyWhileOpen {
        require(now >= startTime && now <= endTime);
        _;
    }
    
    // Initial function
    function APOTokenCrowdsale() public
    Crowdsale(rate, vault, token) 
    {
        wallet = msg.sender;
        bountyWallet = 0x06F05ebdf3b871813f80C4A1744e66357B0d9e44;
        privateWallet = 0xb62109986F19f710415e71F27fAaF4ece89eFf83;
        teamTokens = new TokenTimelock(token, msg.sender, unlockTime);
        reserveTokens = new TokenTimelock(token, 0x2700C56A67F12899a4CB9316ab6541d90EcE52E9, unlockTime);
    }


    function _preValidatePurchase(address _beneficiary, uint256 _weiAmount) internal onlyWhileOpen {
        require(_beneficiary != address(0));
        require(_weiAmount != 0);
        require(_weiAmount >= minAmount);
        require(weiRaised.add(_weiAmount) <= hardCap);
    }
    

    /**
    * @dev Source of tokens. Override this method to modify the way in which the crowdsale ultimately gets and sends its tokens.
    * @param _beneficiary Address performing the token purchase
    * @param _tokenAmount Number of tokens to be emitted
    */
    function _deliverTokens(address _beneficiary, uint256 _tokenAmount) internal {
        // Calculate discount rate
        if (now <= startTime + 1 * discountPeriod) {
            _tokenAmount = _tokenAmount.mul(125).div(100);
        } else if ((now > startTime + 1 * discountPeriod) && (now <= startTime + 2 * discountPeriod))  {
            _tokenAmount = _tokenAmount.mul(115).div(100);
        } else if ((now > startTime + 2 * discountPeriod) && (now <= startTime + 3 * discountPeriod))  {
            _tokenAmount = _tokenAmount.mul(105).div(100);
        }
        
        // Mint token for contributor
        token.mint(_beneficiary, _tokenAmount);
    }


    /**
    * @dev Determines how ETH is stored/forwarded on purchases.
    */
    function _forwardFunds() internal {
        vault.deposit.value(msg.value)(msg.sender);
    }


    /**
    * @dev Checks whether the cap has been reached. 
    * @return Whether the cap was reached
    */
    function capReached() public view returns (bool) {
        return weiRaised >= hardCap;
    }


    /**
    * @dev Must be called after crowdsale ends, to do some extra finalization
    * work. Calls the contract's finalization function.
    */
    function finalize() onlyOwner public {
        require(!isFinalized);
        require(hasClosed());
        
        // Finalize
        finalization();
        emit Finalized();

        isFinalized = true;
    }


    /**
    * @dev Can be overridden to add finalization logic. The overriding function
    * should call super.finalization() to ensure the chain of finalization is
    * executed entirely.
    */
    function finalization() internal {
        // 
        if (goalReached()) {
            
            vault.close();
            
            // For team - 20%, reserve - 25%, bounty - 5%, private investors - 10%
            uint issuedTokenSupply = token.totalSupply();
            uint teamPercent = issuedTokenSupply.mul(20).div(40);
            uint reservePercent = issuedTokenSupply.mul(25).div(40);
            uint bountyPercent = issuedTokenSupply.mul(5).div(40);
            uint privatePercent = issuedTokenSupply.mul(10).div(40);   
            
            // Mint
            token.mint(teamTokens, teamPercent);
            token.mint(reserveTokens, reservePercent);
            token.mint(bountyWallet, bountyPercent);
            token.mint(privateWallet, privatePercent);
            
            // Finish minting
            token.finishMinting();
            
        } else {
            vault.enableRefunds();
            // Finish minting
            token.finishMinting();
        }
        
    }


    /**
    * @dev Checks whether the period in which the crowdsale is open has already elapsed.
    * @return Whether crowdsale period has elapsed
    */
    function hasClosed() public view returns (bool) {
        return now > endTime;
    }


    /**
    * @dev Investors can claim refunds here if crowdsale is unsuccessful
    */
    function claimRefund() public {
        require(isFinalized);
        require(!goalReached());

        vault.refund(msg.sender);
    }
    

    /**
    * @dev Checks whether funding goal was reached. 
    * @return Whether funding goal was reached
    */
    function goalReached() public view returns (bool) {
        return weiRaised >= softCap;
    }

}
