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

event UpdateBlueprint:
    old_blueprint: address
    new_blueprint: address

event UpdateCompass:
    old_compass: address
    new_compass: address

event UpdateRefundWallet:
    old_refund_wallet: address
    new_refund_wallet: address

event SetPaloma:
    paloma: bytes32

event UpdateGasFee:
    old_gas_fee: uint256
    new_gas_fee: uint256

event UpdateServiceFeeCollector:
    old_service_fee_collector: address
    new_service_fee_collector: address

event UpdateServiceFee:
    old_service_fee: uint256
    new_service_fee: uint256

interface Router:
    def sendWnt(receiver: address, amount: uint256): payable
    def sendTokens(token: address, receiver: address, amount: uint256): payable
    def createOrder(params: CreateOrderParams) -> bytes32: nonpayable

interface ERC20:
    def approve(_spender: address, _value: uint256) -> bool: nonpayable
    def transfer(_to: address, _value: uint256) -> bool: nonpayable
    def transferFrom(_from: address, _to: address, _value: uint256) -> bool: nonpayable

MAX_SIZE: constant(uint256) = 8
DENOMINATOR: constant(uint256) = 10**18
GMX_ROUTER: constant(address) = 0x7C68C7866A64FA2160F78EEaE12217FFbf871fa8
blueprint: public(address)
compass: public(address)
refund_wallet: public(address)
gas_fee: public(uint256)
service_fee_collector: public(address)
service_fee: public(uint256)
paloma: public(bytes32)

@external
def deposit(token: address, amount0: uint256, amount1: uint256, params: CreateOrderParams):
    assert ERC20(token).transferFrom(msg.sender, self, amount0, default_return_value=True), "Failed transferFrom"
    assert ERC20(token).approve(GMX_ROUTER, amount0, default_return_value=True), "Failed approve"
    Router(GMX_ROUTER).sendWnt(self, amount0)
    Router(GMX_ROUTER).sendTokens(token, self, amount1)
    Router(GMX_ROUTER).createOrder(params)

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
def update_refund_wallet(new_refund_wallet: address):
    self._paloma_check()
    old_refund_wallet: address = self.refund_wallet
    self.refund_wallet = new_refund_wallet
    log UpdateRefundWallet(old_refund_wallet, new_refund_wallet)

@external
def update_gas_fee(new_gas_fee: uint256):
    self._paloma_check()
    old_gas_fee: uint256 = self.gas_fee
    self.gas_fee = new_gas_fee
    log UpdateGasFee(old_gas_fee, new_gas_fee)

@external
def update_service_fee_collector(new_service_fee_collector: address):
    self._paloma_check()
    old_service_fee_collector: address = self.service_fee_collector
    self.service_fee_collector = new_service_fee_collector
    log UpdateServiceFeeCollector(old_service_fee_collector, new_service_fee_collector)

@external
def update_service_fee(new_service_fee: uint256):
    self._paloma_check()
    old_service_fee: uint256 = self.service_fee
    self.service_fee = new_service_fee
    log UpdateServiceFee(old_service_fee, new_service_fee)

@external
@payable
def __default__():
    pass