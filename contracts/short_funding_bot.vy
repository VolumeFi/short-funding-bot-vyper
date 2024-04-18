#pragma version 0.3.10
#pragma optimize gas
#pragma evm-version paris
"""
@title Short Funding Bot
@license Apache 2.0
@author Volume.finance
"""

struct CreateOrderParamsAddresses:
    receiver: address
    callbackContract: address
    uiFeeReceiver: address
    market: address
    initialCollateralToken: address
    swapPath: DynArray[address, MAX_SIZE]

struct CreateOrderParamsNumbers:
    sizeDeltaUsd: uint256
    initialCollateralDeltaAmount: uint256
    triggerPrice: uint256
    acceptablePrice: uint256
    executionFee: uint256
    callbackGasLimit: uint256
    minOutputAmount: uint256

enum OrderType:
    MarketSwap
    LimitSwap
    MarketIncrease
    LimitIncrease
    MarketDecrease
    LimitDecrease
    StopLossDecrease
    Liquidation

enum DecreasePositionSwapType:
    NoSwap
    SwapPnlTokenToCollateralToken
    SwapCollateralTokenToPnlToken

struct CreateOrderParams:
    addresses: CreateOrderParamsAddresses
    numbers: CreateOrderParamsNumbers
    orderType: OrderType
    decreasePositionSwapType: DecreasePositionSwapType
    isLong: bool
    shouldUnwrapNativeToken: bool
    referralCode: bytes32

interface Router:
    def sendWnt(receiver: address, amount: uint256): payable
    def sendTokens(token: address, receiver: address, amount: uint256): payable
    def createOrder(params: CreateOrderParams) -> bytes32: nonpayable

interface ERC20:
    def balanceOf(_owner: address) -> uint256: view
    def transfer(_to: address, _value: uint256) -> bool: nonpayable
    def transferFrom(_from: address, _to: address, _value: uint256) -> bool: nonpayable

MAX_SIZE: constant(uint256) = 8
DENOMINATOR: constant(uint256) = 10**18
GMX_ROUTER: constant(address) = 0x7C68C7866A64FA2160F78EEaE12217FFbf871fa8
ORDER_VAULT: constant(address) = 0x31eF83a530Fde1B38EE9A18093A333D8Bbbc40D5
USDC: constant(address) = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831
WETH: constant(address) = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1
GMX_MARKET: constant(address) = 0x6853EA96FF216fAb11D2d930CE3C508556A4bdc4
FACTORY: public(immutable(address))
OWNER: public(immutable(address))

@external
def __init__(owner: address):
    OWNER = owner
    FACTORY = msg.sender

@external
@payable
def deposit(amount0: uint256, order_params: CreateOrderParams, swap_min_amount: uint256) -> uint256:
    assert ERC20(USDC).transferFrom(msg.sender, GMX_ROUTER, amount0, default_return_value=True), "Failed transferFrom"
    Router(GMX_ROUTER).createOrder(order_params)
    swap_params: CreateOrderParams = CreateOrderParams({
        addresses: CreateOrderParamsAddresses({
            receiver: self,
            callbackContract: empty(address),
            uiFeeReceiver: empty(address),
            market: empty(address),
            initialCollateralToken: USDC,
            swapPath: [GMX_MARKET]
        }),
        numbers: CreateOrderParamsNumbers({
            sizeDeltaUsd: 0,
            initialCollateralDeltaAmount: 0,
            triggerPrice: 0,
            acceptablePrice: 0,
            executionFee: 0,
            callbackGasLimit: 0,
            minOutputAmount: swap_min_amount
        }),
        orderType: OrderType.MarketSwap,
        decreasePositionSwapType: DecreasePositionSwapType.NoSwap,
        isLong: False,
        shouldUnwrapNativeToken: False,
        referralCode: empty(bytes32)
    })
    bal: uint256 = ERC20(WETH).balanceOf(self)
    Router(GMX_ROUTER).createOrder(swap_params)
    bal = ERC20(WETH).balanceOf(self) - bal
    return bal

@external
@payable
def withdraw(amount0: uint256, amount1: uint256, order_params: CreateOrderParams, swap_min_amount: uint256) -> uint256:
    assert msg.sender == OWNER or msg.sender == FACTORY
    Router(GMX_ROUTER).createOrder(order_params)
    swap_params: CreateOrderParams = CreateOrderParams({
        addresses: CreateOrderParamsAddresses({
            receiver: OWNER,
            callbackContract: empty(address),
            uiFeeReceiver: empty(address),
            market: empty(address),
            initialCollateralToken: WETH,
            swapPath: [GMX_MARKET]
        }),
        numbers: CreateOrderParamsNumbers({
            sizeDeltaUsd: 0,
            initialCollateralDeltaAmount: 0,
            triggerPrice: 0,
            acceptablePrice: 0,
            executionFee: 0,
            callbackGasLimit: 0,
            minOutputAmount: swap_min_amount
        }),
        orderType: OrderType.MarketSwap,
        decreasePositionSwapType: DecreasePositionSwapType.NoSwap,
        isLong: False,
        shouldUnwrapNativeToken: True,
        referralCode: empty(bytes32)
    })
    assert ERC20(WETH).transfer(GMX_ROUTER, amount0, default_return_value=True), "Failed transfer"
    bal: uint256 = ERC20(USDC).balanceOf(OWNER)
    Router(GMX_ROUTER).createOrder(swap_params)
    assert ERC20(USDC).transfer(OWNER, amount1, default_return_value=True), "Failed transfer"
    bal = ERC20(USDC).balanceOf(OWNER) - bal
    return bal

@external
@payable
def __default__():
    pass