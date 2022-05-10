// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";

contract APIConsumer is ChainlinkClient {
    using Chainlink for Chainlink.Request;
  
    struct Post {
        address author;
        address[] tweeters;
        address finder;
        uint reward;
        uint tweeterNumber;
    }

    bool public validated;
    
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;
    string constant baseUrl = "https://infinite-earth-88810.herokuapp.com/scrape?username=";

    // Mapping to store the request id with the corresponding result
    mapping(bytes32 => bool) requestResults;

    // Mapping to store postId with the corresponding post
    mapping(uint => Post) posts;

    // Reverse mapping to store relation of postId and username to requestId
    mapping(bytes32 => bytes32) hashRequestMapping;

    // Mapping to store userNames with addresses
    mapping(bytes32 => address) userAddresses;

    mapping(bytes32 => uint) requestIdPostMapping;

    mapping(bytes32 => address) userRequests;



    constructor() {
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
        oracle = 0x0bDDCD124709aCBf9BB3F824EbC61C87019888bb;
        jobId = "a79e6eaf562f4be981d601cfbf8f8d84";
        fee = 0.01 * 10 ** 18; 
    }
    

    function submitValidationRequest(string memory requestUrl) public returns (bytes32 requestId) {
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);
    
        request.add("get", requestUrl );
        request.add("path", "validated"); 
        
        return sendChainlinkRequestTo(oracle, request, fee);
    }
    

    function fulfill(bytes32 _requestId, bool _validated) public recordChainlinkFulfillment(_requestId){
        requestResults[_requestId] = _validated;
        if (_validated) {
            Post storage post = posts[requestIdPostMapping[_requestId]];
            post.tweeters[post.tweeterNumber] = userRequests[_requestId];
            if(post.tweeters[post.tweeterNumber] != address(0)){
                post.tweeterNumber = post.tweeterNumber + 1;
            }
        }
    }

    function validateUser(string memory _userName,uint _postId) public returns (bytes32){
        string memory requestUrl = string(abi.encodePacked(baseUrl,_userName));
        bytes32 reqId = (submitValidationRequest(requestUrl));

        bytes32 hashId = keccak256(bytes(string(abi.encodePacked(_userName,_postId))));
        hashRequestMapping[hashId] = reqId;

        requestIdPostMapping[reqId] = _postId;

        userRequests[reqId] = userAddresses[keccak256(bytes(_userName))];
        return reqId;
   }
    function registerPost(uint _postId,uint _reward) public {
        Post storage post= posts[_postId];
        post.reward = _reward;
        post.author = msg.sender;
        post.tweeters = new address[](10);
        post.tweeterNumber = 0;
    }

    function getPost(uint _postId) public view returns (Post memory){
            return posts[_postId];
    }

    function registerUser(string memory _userName) public {
        userAddresses[keccak256(bytes(_userName))] = msg.sender;
    }

    function getUserAddress(string memory _userName) public view returns (address){
        return userAddresses[keccak256(bytes(_userName))];
    }

    function getUserValidatedByPost(string memory _userName, uint postId) public view returns (bool){
        bytes32 hashId = keccak256(bytes(string(abi.encodePacked(_userName,postId))));
        return requestResults[hashRequestMapping[hashId]];
    }

}
