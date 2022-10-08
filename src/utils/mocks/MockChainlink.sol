pragma solidity ^0.8.0;



contract MockChainlink {

    int96 public ethPrice = 200000000000;
  
    function latestAnswer() external view returns(int96) {
        return ethPrice;
    }

    function updateAnswer(int96 _newPrice) external {
        ethPrice = _newPrice;
    }
}