// File: contracts/WizardPresaleInterface.sol

pragma solidity >=0.5.6 <0.6.0;


/// @title WizardPresaleInterface
/// @notice This interface represents the single method that the final tournament and master Wizard contracts
///         will use to import the presale wizards when those contracts have been finalized a released on
///         mainnet. Once all presale Wizards have been absorbed, this temporary pre-sale contract can be
///         destroyed.
contract WizardPresaleInterface {

    // See https://github.com/ethereum/EIPs/blob/master/EIPS/eip-165.md on how
    // to calculate this
    bytes4 public constant _INTERFACE_ID_WIZARDPRESALE = 0x4df71efb;

    /// @notice This function is used to bring a presale Wizard into the final contracts. It can
    ///         ONLY be called by the official gatekeeper contract (as set by the Owner of the presale
    ///         contract). It does a number of things:
    ///            1. Check that the presale Wizard exists, and has not already been absorbed
    ///            2. Transfer the Eth used to create the presale Wizard to the caller
    ///            3. Mark the Wizard as having been absorbed, reclaiming the storage used by the presale info
    ///            4. Return the Wizard information (its owner, minting price, and elemental alignment)
    /// @param id the id of the presale Wizard to be absorbed
    function absorbWizard(uint256 id) external returns (address owner, uint256 power, uint8 affinity);

    /// @notice A convenience function that allows multiple Wizards to be moved to the final contracts
    ///         simultaneously, works the same as the previous function, but in a batch.
    /// @param ids An array of ids indicating which presale Wizards are to be absorbed
    function absorbWizardMulti(uint256[] calldata ids) external
        returns (address[] memory owners, uint256[] memory powers, uint8[] memory affinities);

    function powerToCost(uint256 power) public pure returns (uint256 cost);
    function costToPower(uint256 cost) public pure returns (uint256 power);
}
