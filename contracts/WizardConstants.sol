// File: contracts/WizardConstants.sol

pragma solidity >=0.5.6 <0.6.0;

/// @title The master organization behind wizardry activity, where Wiz come from.
contract WizardConstants {
    uint8 internal constant ELEMENT_NOTSET = 0;
    // need to decide what neutral is because of price difference
    uint8 internal constant ELEMENT_NEUTRAL = 1;
    // no sense in defining these here as they are probably not fixed,
    // all we need to know is that these are not neutral
    uint8 internal constant ELEMENT_FIRE = 2;
    uint8 internal constant ELEMENT_WIND = 3;
    uint8 internal constant ELEMENT_WATER = 4;
    uint8 internal constant MAX_ELEMENT = ELEMENT_WATER;
}
