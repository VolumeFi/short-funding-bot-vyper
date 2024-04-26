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

interface Factory:
    def deposited_event(amount0: uint256, order_params: CreateOrderParams): nonpayable
    def withdrawn_event(amount0: uint256, order_params: CreateOrderParams): nonpayable
    def canceled_event(): nonpayable

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
    if msg.sender == OWNER:
        self._safe_transfer_from(USDC, OWNER, GMX_ROUTER, unsafe_div(amount0, 2))
    else:
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
    if msg.sender == OWNER:
        self._safe_transfer_from(USDC, msg.sender, GMX_ROUTER, unsafe_div(amount0, 2))
        Factory(FACTORY).deposited_event(amount0, order_params)
    else:
        self._check_sender(msg.sender, FACTORY)
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
    Factory(FACTORY).withdrawn_event(amount0, order_params)
    return bal

@external
def withdraw(amount0: uint256, order_params: CreateOrderParams, swap_min_amount: uint256) -> uint256:
    self._check_sender(msg.sender, FACTORY)
    return self._withdraw(amount0, order_params, swap_min_amount)

@external
def withdraw_and_end_bot(amount0: uint256, order_params: CreateOrderParams, swap_min_amount: uint256) -> uint256:
    self._check_sender(msg.sender, OWNER)
    amount: uint256 = self._withdraw(amount0, order_params, swap_min_amount)
    self._safe_transfer(USDC, OWNER, ERC20(USDC).balanceOf(self))
    return amount

@external
def end_bot():
    self._check_sender(msg.sender, OWNER)
    self._safe_transfer(USDC, OWNER, ERC20(USDC).balanceOf(self))
    Factory(FACTORY).canceled_event()

@external
@payable
def __default__():
    pass
