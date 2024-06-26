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
GMX_ROUTER: immutable(address)
USDC: immutable(address)
WETH: immutable(address)
GMX_MARKET: immutable(address)
FACTORY: public(immutable(address))
OWNER: public(immutable(address))

@external
def __init__(owner: address, _gmx_router: address, _usdc: address, _weth: address, _gmx_market: address):
    OWNER = owner
    FACTORY = msg.sender
    GMX_ROUTER = _gmx_router
    USDC = _usdc
    WETH = _weth
    GMX_MARKET = _gmx_market

@internal
def _safe_transfer(_token: address, _to: address, _value: uint256):
    assert ERC20(_token).transfer(_to, _value, default_return_value=True), "Failed transfer"

@internal
def _safe_transfer_from(_token: address, _from: address, _to: address, _value: uint256):
    assert ERC20(_token).transferFrom(_from, _to, _value, default_return_value=True), "Failed transferFrom"

@internal
def _check_sender(_addr0: address, _addr1: address):
    assert _addr0 == _addr1, "Unauthorized"

@external
def deposit(amount0: uint256, order_params: CreateOrderParams, swap_min_amount: uint256) -> uint256:
    self._check_sender(msg.sender, FACTORY)
    self._safe_transfer(USDC, GMX_ROUTER, unsafe_div(amount0, 2))
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
    self._safe_transfer(USDC, GMX_ROUTER, unsafe_div(amount0, 2))
    Router(GMX_ROUTER).createOrder(swap_params)
    bal = ERC20(WETH).balanceOf(self) - bal
    return bal

@internal
def _withdraw(amount0: uint256, order_params: CreateOrderParams, swap_min_amount: uint256) -> uint256:
    Router(GMX_ROUTER).createOrder(order_params)
    swap_params: CreateOrderParams = CreateOrderParams({
        addresses: CreateOrderParamsAddresses({
            receiver: self,
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
    self._safe_transfer(WETH, GMX_ROUTER, amount0)
    bal: uint256 = ERC20(USDC).balanceOf(self)
    Router(GMX_ROUTER).createOrder(swap_params)
    bal = ERC20(USDC).balanceOf(self) - bal
    return bal

@external
def withdraw(amount0: uint256, order_params: CreateOrderParams, swap_min_amount: uint256) -> uint256:
    self._check_sender(msg.sender, FACTORY)
    return self._withdraw(amount0, order_params, swap_min_amount)

@internal
def _swap_and_exit(markets: DynArray[address, MAX_SIZE], expected_token: address, _min_amount: uint256) -> uint256:
    swap_params: CreateOrderParams = CreateOrderParams({
        addresses: CreateOrderParamsAddresses({
            receiver: OWNER,
            callbackContract: empty(address),
            uiFeeReceiver: empty(address),
            market: empty(address),
            initialCollateralToken: USDC,
            swapPath: markets
        }),
        numbers: CreateOrderParamsNumbers({
            sizeDeltaUsd: 0,
            initialCollateralDeltaAmount: 0,
            triggerPrice: 0,
            acceptablePrice: 0,
            executionFee: 0,
            callbackGasLimit: 0,
            minOutputAmount: _min_amount
        }),
        orderType: OrderType.MarketSwap,
        decreasePositionSwapType: DecreasePositionSwapType.NoSwap,
        isLong: False,
        shouldUnwrapNativeToken: True,
        referralCode: empty(bytes32)
    })
    amount0: uint256 = ERC20(USDC).balanceOf(self)
    self._safe_transfer(USDC, GMX_ROUTER, amount0)
    _bal: uint256 = ERC20(expected_token).balanceOf(OWNER)
    Router(GMX_ROUTER).createOrder(swap_params)
    _bal = ERC20(expected_token).balanceOf(OWNER) - _bal
    assert _bal >= _min_amount, "High Slippage"
    return _bal

@external
def withdraw_and_end_bot(amount0: uint256, order_params: CreateOrderParams, markets: DynArray[address, MAX_SIZE], expected_token: address, _min_amount: uint256) -> uint256:
    self._check_sender(msg.sender, FACTORY)
    self._withdraw(amount0, order_params, 0)
    _bal: uint256 = self._swap_and_exit(markets, expected_token, _min_amount)
    return _bal

@external
def end_bot(markets: DynArray[address, MAX_SIZE], expected_token: address, _min_amount: uint256) -> uint256:
    self._check_sender(msg.sender, FACTORY)
    _bal: uint256 = self._swap_and_exit(markets, expected_token, _min_amount)
    return _bal

@external
@payable
def __default__():
    pass
