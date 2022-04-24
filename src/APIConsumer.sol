// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "chainlink/contracts/src/v0.8/ChainlinkClient.sol";

contract APIConsumer is ChainlinkClient {
    using Chainlink for Chainlink.Request;
  
    uint256 public floorPrice;
    
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;

    string public name;
    string public slug;
    string public url;
    
    /**
     * Network: Kovan
     * Oracle: 0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8 (Chainlink Devrel   
     * Node)
     * Job ID: d5270d1c311941d0b08bead21fea7747
     * Fee: 0.1 LINK
     */
    constructor() {
      setPublicChainlinkToken();
      oracle = 0x0a31078cD57d23bf9e8e8F1BA78356ca2090569E;
      jobId = "23c942bf9a8b46fba06bd1a15161205a";
      fee = 0.01 * 10 ** 18; // (Varies by network and job)

      name = "Oracle";
      slug = "proof-moonbirds";
      url = "https://api.opensea.io/collection/proof-moonbirds";
    }
    
    /**
     * Create a Chainlink request to retrieve API response, find the target
     * data, then multiply by 1000000000000000000 (to remove decimal places from data).
     */
    function requestVolumeData() public returns (bytes32 requestId) 
    {
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);
        
        // Set the URL to perform the GET request on
        request.add("get", url);

        request.add("path", "collection.stats.floor_price"); // Chainlink nodes 1.0.0 and later support this format
        
        // Multiply the result by 1000000000000000000 to remove decimals
        int timesAmount = 10**18;
        request.addInt("times", timesAmount);
        
        // Sends the request
        return sendChainlinkRequestTo(oracle, request, fee);
    }
    
    /**
     * Receive the response in the form of uint256
     */ 
    function fulfill(bytes32 _requestId, uint256 _floorPrice) public recordChainlinkFulfillment(_requestId)
    {
        floorPrice = _floorPrice;
    }

    // function withdrawLink() external {} - Implement a withdraw function to avoid locking your LINK in the contract
}

