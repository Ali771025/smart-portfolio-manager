"""Factory for broker parser implementations."""

from __future__ import annotations

from .agah_parser import AgahParser
from .base_parser import BaseBrokerParser, BrokerType
from .boursiran_parser import BoursiranParser
from .gandam_parser import GandamParser
from .mofid_parser import MofidParser


def build_parser_for_broker(broker: BrokerType) -> BaseBrokerParser:
    if broker == BrokerType.MOFID:
        return MofidParser()
    if broker == BrokerType.AGAH:
        return AgahParser()
    if broker == BrokerType.BOURSIRAN:
        return BoursiranParser()
    if broker == BrokerType.GANDAM:
        return GandamParser()
    raise ValueError(f"No parser registered for broker={broker}")

