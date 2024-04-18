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

event BotDeployed:
    owner: address
    bot: address

event UpdateBlueprint:
    old_blueprint: address
    new_blueprint: address

event UpdateCompass:
    old_compass: address
    new_compass: address

event SetPaloma:
    paloma: bytes32


interface Bot:
    def withdraw(amount0: uint256, amount1: uint256, order_params: CreateOrderParams, swap_min_amount: uint256) -> uint256:nonpayable

interface Router:
    def sendWnt(receiver: address, amount: uint256): payable
    def sendTokens(token: address, receiver: address, amount: uint256): payable
    def createOrder(params: CreateOrderParams) -> bytes32: nonpayable

interface ERC20:
    def balanceOf(_owner: address) -> uint256: view
    def approve(_spender: address, _value: uint256) -> bool: nonpayable
    def transfer(_to: address, _value: uint256) -> bool: nonpayable
    def transferFrom(_from: address, _to: address, _value: uint256) -> bool: nonpayable

MAX_SIZE: constant(uint256) = 8
DENOMINATOR: constant(uint256) = 10**18
GMX_ROUTER: constant(address) = 0x7C68C7866A64FA2160F78EEaE12217FFbf871fa8
ORDER_VAULT: constant(address) = 0x31eF83a530Fde1B38EE9A18093A333D8Bbbc40D5
USDC: constant(address) = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831
WETH: constant(address) = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1
GMX_MARKET: constant(address) = 0x6853EA96FF216fAb11D2d930CE3C508556A4bdc4
blueprint: public(address)
compass: public(address)
paloma: public(bytes32)

@external
def __init__(_blueprint: address, _compass: address):
    self.blueprint = _blueprint
    self.compass = _compass
    log UpdateCompass(empty(address), _compass)
    log UpdateBlueprint(empty(address), _blueprint)

@external
def deploy_bot():
    bot: address = create_from_blueprint(self.blueprint, msg.sender)
    log BotDeployed(msg.sender, bot)

@external
def withdraw(bot: address, amount0: uint256, amount1: uint256, order_params: CreateOrderParams, swap_min_amount: uint256) -> uint256:
    self._paloma_check()
    return Bot(bot).withdraw(amount0, amount1, order_params, swap_min_amount)

@internal
def _paloma_check():
    assert msg.sender == self.compass, "Not compass"
    assert self.paloma == convert(slice(msg.data, unsafe_sub(len(msg.data), 32), 32), bytes32), "Invalid paloma"

@external
def update_compass(new_compass: address):
    self._paloma_check()
    self.compass = new_compass
    log UpdateCompass(msg.sender, new_compass)

@external
def update_blueprint(new_blueprint: address):
    self._paloma_check()
    old_blueprint: address = self.blueprint
    self.blueprint = new_blueprint
    log UpdateCompass(old_blueprint, new_blueprint)

@external
def set_paloma():
    assert msg.sender == self.compass and self.paloma == empty(bytes32) and len(msg.data) == 36, "Invalid"
    _paloma: bytes32 = convert(slice(msg.data, 4, 32), bytes32)
    self.paloma = _paloma
    log SetPaloma(_paloma)

@external
@payable
def __default__():
    pass