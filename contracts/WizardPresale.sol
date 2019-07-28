/**
 * Source Code first verified at https://etherscan.io on Saturday, May 18, 2019
 (UTC) */

// File: contracts/WizardPresale.sol

pragma solidity >=0.5.6 <0.6.0;

import "./AddressPayable.sol";
import "./WizardPresaleNFT.sol";
import "./WizardPresaleInterface.sol";
import "./WizardConstants.sol";

/// @title WizardPresale - Making Cheeze Wizards available for sale!
/// @notice Allows for the creation and sale of Cheeze Wizards before the final tournament
///         contract has been reviewed and released on mainnet. There are three main types
///         of Wizards that are managed by this contract:
///          - Neutral Wizards: Available in unlimited quantities and all have the same
///             innate power. Don't have a natural affinity for any particular elemental
///             spell... or the corresponding weakness!
///          - Elemental Wizards: Available in unlimited quantities, but with a steadily increasing
///             power; the power of an Elemental Wizard is always _slightly_ higher than the power
///             of the previously created Elemental Wizard. Each Elemental Wizard has an Elemental
///             Affinity that gives it a power multiplier when using the associated spell, but also
///             gives it a weakness for the opposing element.
///          - Exclusive Wizards: Only available in VERY limited quantities, with a hard cap set at
///             contract creation time. Exclusive Wizards can ONLY be created by the Guild Master
///             address (the address that created this contract), and are assigned the first N
///             Wizard IDs, starting with 1 (where N is the hard cap on Exclusive Wizards). The first
///             non-exclusive Wizard is assigned the ID N+1. Exclusive Wizards have no starting
///             affinity, and their owners much choose an affinity before they can be entered into a
///             Battle. The affinity CAN NOT CHANGE once it has been selected. The power of Exclusive
///             Wizards is not set by the Guild Master and is not required to follow any pattern (although
///             it can't be lower than the power of Neutral Wizards).
contract WizardPresale is AddressPayable, WizardPresaleNFT, WizardPresaleInterface, WizardConstants {

    /// @dev The ratio between the cost of a Wizard (in wei) and the power of the wizard.
    ///      power = cost / POWER_SCALE
    ///      cost = power * POWER_SCALE
    uint256 private constant POWER_SCALE = 1000;

    /// @dev The unit conversion for tenths of basis points
    uint256 private constant TENTH_BASIS_POINTS = 100000;

    /// @dev The address used to create this smart contract, has permission to conjure Exclusive Wizards,
    ///      set the gatekeeper address, and destroy this contract once the sale is finished and all Presale
    ///      Wizards have been absorbed into the main contracts.
    address payable public guildmaster;

    /// @dev The start block and duration (in blocks) of the sale.
    ///      ACT NOW! For a limited time only!
    uint256 public saleStartBlock;
    uint256 public saleDuration;

    /// @dev The cost of Neutral Wizards (in wei).
    uint256 public neutralWizardCost;

    /// @dev The cost of the _next_ Elemental Wizard (in wei); increases with each Elemental Wizard sold
    uint256 public elementalWizardCost;

    /// @dev The increment ratio in price between sequential Elemental Wizards, multiplied by 100k for
    ///      greater granularity (0 == 0% increase, 100000 == 100% increase, 100 = 0.1% increase, etc.)
    ///      NOTE: This is NOT percentage points, or basis points. It's tenths of a basis point.
    uint256 public elementalWizardIncrement;

    /// @dev The hard cap on how many Exclusive Wizards can be created
    uint256 public maxExclusives;

    /// @dev The ID number of the next Wizard to be created (Neutral or Elemental)
    uint256 public nextWizardId;

    /// @dev The address of the Gatekeeper for the tournament, initially set to address(0).
    ///      To be set by the Guild Master when the final Tournament Contract is deployed on mainnet
    address payable public gatekeeper;

    /// @notice Emitted whenever the start of the sale changes.
    event StartBlockChanged(uint256 oldStartBlock, uint256 newStartBlock);

    /// @param startingCost The minimum cost of a Wizard, used as the price for all Neutral Wizards, and the
    ///        cost of the first Elemental Wizard. Also used as a minimum value for Exclusive Wizards.
    /// @param costIncremement The rate (in tenths of a basis point) at which the price of Elemental Wizards increases
    /// @param exclusiveCount The hard cap on Exclusive Wizards, also dictates the ID of the first non-Exclusive
    /// @param startBlock The starting block of the presale.
    /// @param duration The duration of the presale.  Not changeable!
    constructor(uint128 startingCost,
            uint16 costIncremement,
            uint256 exclusiveCount,
            uint128 startBlock,
            uint128 duration) public
    {
        require(startBlock > block.number, "start must be greater than current block");

        guildmaster = msg.sender;
        saleStartBlock = startBlock;
        saleDuration = duration;
        neutralWizardCost = startingCost;
        elementalWizardCost = startingCost;
        elementalWizardIncrement = costIncremement;
        maxExclusives = exclusiveCount;
        nextWizardId = exclusiveCount + 1;

        _registerInterface(_INTERFACE_ID_WIZARDPRESALE);
    }

    /// @dev Throws if called by any account other than the gatekeeper.
    modifier onlyGatekeeper() {
        require(msg.sender == gatekeeper, "Must be gatekeeper");
        _;
    }

    /// @dev Throws if called by any account other than the guildmaster.
    modifier onlyGuildmaster() {
        require(msg.sender == guildmaster, "Must be guildmaster");
        _;
    }

    /// @dev Checks to see that the current block number is within the range
    ///      [saleStartBlock, saleStartBlock + saleDuraction) indicating that the sale
    ///      is currently active
    modifier onlyDuringSale() {
        // The addtion of start and duration can't overflow since they can only be set from
        // 128-bit arguments.
        require(block.number >= saleStartBlock, "Sale not open yet");
        require(block.number < saleStartBlock + saleDuration, "Sale closed");
        _;
    }

    /// @dev Sets the address of the Gatekeeper contract once the final Tournament contract is live.
    ///      Can only be set once.
    /// @param gc The gatekeeper address to set
    function setGatekeeper(address payable gc) external onlyGuildmaster {
        require(gatekeeper == address(0) && gc != address(0), "Can only set once and must not be zero");
        gatekeeper = gc;
    }

    /// @dev Updates the start block of the sale. The sale can only be postponed; it can't be made earlier.
    /// @param newStart the new start block.
    function postponeSale(uint128 newStart) external onlyGuildmaster {
        require(block.number < saleStartBlock, "Sale start time only adjustable before previous start time");
        require(newStart > saleStartBlock, "New start time must be later than previous start time");

        emit StartBlockChanged(saleStartBlock, newStart);

        saleStartBlock = newStart;
    }

    /// @dev Returns true iff the sale is currently active
    function isDuringSale() external view returns (bool) {
        return (block.number >= saleStartBlock && block.number < saleStartBlock + saleDuration);
    }

    /// @dev Convenience method for getting a presale wizard's data
    /// @param id The wizard id
    function getWizard(uint256 id) public view returns (address owner, uint88 power, uint8 affinity) {
        Wizard memory wizard = _wizardsById[id];
        (owner, power, affinity) = (wizard.owner, wizard.power, wizard.affinity);
        require(wizard.owner != address(0), "Wizard does not exist");
    }

    /// @param cost The price of the wizard in wei
    /// @return The power of the wizard (left as uint256)
    function costToPower(uint256 cost) public pure returns (uint256 power) {
        return cost / POWER_SCALE;
    }

    /// @param power The power of the wizard
    /// @return The cost of the wizard in wei
    function powerToCost(uint256 power) public pure returns (uint256 cost) {
        return power * POWER_SCALE;
    }

    /// @notice This function is used to bring a presale Wizard into the final contracts. It can
    ///         ONLY be called by the official gatekeeper contract (as set by the Owner of the presale
    ///         contract). It does a number of things:
    ///            1. Check that the presale Wizard exists, and has not already been absorbed
    ///            2. Transfer the Eth used to create the presale Wizard to the caller
    ///            3. Mark the Wizard as having been absorbed, reclaiming the storage used by the presale info
    ///            4. Return the Wizard information (its owner, minting price, and elemental alignment)
    /// @param id the id of the presale Wizard to be absorbed
    function absorbWizard(uint256 id) external onlyGatekeeper returns (address owner, uint256 power, uint8 affinity) {
        (owner, power, affinity) = getWizard(id);

        // Free up the storage used by this wizard
        _burn(owner, id);

        // send the price paid to the gatekeeper to be used in the tournament prize pool
        msg.sender.transfer(powerToCost(power));
    }

    /// @notice A convenience function that allows multiple Wizards to be moved to the final contracts
    ///         simultaneously, works the same as the previous function, but in a batch.
    /// @param ids An array of ids indicating which presale Wizards are to be absorbed
    function absorbWizardMulti(uint256[] calldata ids) external onlyGatekeeper
            returns (address[] memory owners, uint256[] memory powers, uint8[] memory affinities)
    {
        // allocate arrays
        owners = new address[](ids.length);
        powers = new uint256[](ids.length);
        affinities = new uint8[](ids.length);

        // The total eth to send (sent in a batch to save gas)
        uint256 totalTransfer;

        // Put the data for each Wizard into the returned arrays
        for (uint256 i = 0; i < ids.length; i++) {
            (owners[i], powers[i], affinities[i]) = getWizard(ids[i]);

            // Free up the storage used by this wizard
            _burn(owners[i], ids[i]);

            // add the amount to transfer
            totalTransfer += powerToCost(powers[i]);
        }

        // Send all the eth together
        msg.sender.transfer(totalTransfer);
    }

    /// @dev Internal function to create a new Wizard; reverts if the Wizard ID is taken.
    ///      NOTE: This function heavily depends on the internal format of the Wizard struct
    ///      and should always be reassessed if anything about that structure changes.
    /// @param tokenId ID of the new Wizard
    /// @param owner The address that will own the newly conjured Wizard
    /// @param power The power level associated with the new Wizard
    /// @param affinity The elemental affinity of the new Wizard
    function _createWizard(uint256 tokenId, address owner, uint256 power, uint8 affinity) internal {
        require(!_exists(tokenId), "Can't reuse Wizard ID");
        require(owner != address(0), "Owner address must exist");
        require(power > 0, "Wizard power must be non-zero");
        require(power < (1<<88), "Wizard power must fit in 88 bits of storage.");
        require(affinity <= MAX_ELEMENT, "Invalid elemental affinity");

        // Create the Wizard!
        _wizardsById[tokenId] = Wizard(affinity, uint88(power), owner);
        _ownedTokensCount[owner]++;

        // Tell the world!
        emit Transfer(address(0), owner, tokenId);
        emit WizardSummoned(tokenId, affinity, power);
    }

    /// @dev A private utility function that refunds any overpayment to the sender; smart
    ///      enough to only send the excess if the amount we are returning is more than the
    ///      cost of sending it!
    /// @dev Warning! This does not check for underflows (msg.value < actualPrice) - so
    ///      be sure to call this with correct values!
    /// @param actualPrice the actual price owed
    function _transferRefund(uint256 actualPrice) private {
        uint256 refund = msg.value - actualPrice;

        // Make sure the amount we're trying to refund is less than the actual cost of sending it!
        // See https://github.com/ethereum/wiki/wiki/Subtleties for magic values costs.  We can
        // safley ignore the 25000 additional gas cost for new accounts, as msg.sender is
        // guarunteed to exist at this point!
        if (refund > (tx.gasprice * (9000+700))) {
            msg.sender.transfer(refund);
        }
    }

    /// @notice Conjures an Exclusive Wizard with a specific element and ID. This can only be done by
    ///         the Guildmaster, who still has to pay for the power imbued in that Wizard! The power level
    ///         is inferred by the amount of Eth sent. MUST ONLY BE USED FOR EXTERNAL OWNER ADDRESSES.
    /// @param id The ID of the new Wizard; must be in the Exclusive range, and can't already be allocated
    /// @param owner The address which will own the new Wizard
    /// @param affinity The elemental affinity of the new Wizard, can be ELEMENT_NOTSET for Exclusives!
    function conjureExclusiveWizard(uint256 id, address owner, uint8 affinity) public payable onlyGuildmaster {
        require(id > 0 && id <= maxExclusives, "Invalid exclusive ID");
        _createWizard(id, owner, costToPower(msg.value), affinity);
    }

    /// @notice Same as conjureExclusiveWizard(), but reverts if the owner address is a smart
    ///         contract that is not ERC-721 aware.
    /// @param id The ID of the new Wizard; must be in the Exclusive range, and can't already be allocated
    /// @param owner The address which will own the new Wizard
    /// @param affinity The elemental affinity of the new Wizard, can be ELEMENT_NOTSET for Exclusives!
    function safeConjureExclusiveWizard(uint256 id, address owner, uint8 affinity) external payable onlyGuildmaster {
        conjureExclusiveWizard(id, owner, affinity);
        require(_checkOnERC721Received(address(0), owner, id, ""), "must support erc721");
    }

    /// @notice Allows for the batch creation of Exclusive Wizards. Same rules apply as above, but the
    ///         powers are specified instead of being inferred. The message still needs to have enough
    ///         value to pay for all the newly conjured Wizards!  MUST ONLY BE USED FOR EXTERNAL OWNER ADDRESSES.
    /// @param ids An array of IDs of the new Wizards
    /// @param owners An array of owners
    /// @param powers An array of power levels
    /// @param affinities An array of elemental affinities
    function conjureExclusiveWizardMulti(
        uint256[] calldata ids,
        address[] calldata owners,
        uint256[] calldata powers,
        uint8[] calldata affinities) external payable onlyGuildmaster
    {
        // Ensure the arrays are all of the same length
        require(
            ids.length == owners.length &&
            owners.length == powers.length &&
            owners.length == affinities.length,
            "Must have equal array lengths"
        );

        uint256 totalPower = 0;

        for (uint256 i = 0; i < ids.length; i++) {
            require(ids[i] > 0 && ids[i] <= maxExclusives, "Invalid exclusive ID");
            require(affinities[i] <= MAX_ELEMENT, "Must choose a valid elemental affinity");

            _createWizard(ids[i], owners[i], powers[i], affinities[i]);

            totalPower += powers[i];
        }

        // Ensure that the message includes enough eth to cover the total power of all Wizards
        // If this check fails, all the Wizards that we just created will be deleted, and we'll just
        // have wasted a bunch of gas. Don't be dumb, Guildmaster!
        // If the guildMaster has managed to overflow totalPower, well done!
        require(powerToCost(totalPower) <= msg.value, "Must pay for power in all Wizards");

        // We don't return "change" if the caller overpays, because the caller is the Guildmaster and
        // shouldn't be dumb like that. How many times do I have to say it? Don't be dumb, Guildmaster!
    }

    /// @notice Sets the affinity for a Wizard that doesn't already have its elemental affinity chosen.
    ///         Only usable for Exclusive Wizards (all non-Exclusives must have their affinity chosen when
    ///         conjured.) Even Exclusives can't change their affinity once it's been chosen.
    /// @param wizardId The id of the wizard
    /// @param newAffinity The new affinity of the wizard
    function setAffinity(uint256 wizardId, uint8 newAffinity) external {
        require(newAffinity > ELEMENT_NOTSET && newAffinity <= MAX_ELEMENT, "Must choose a valid affinity");
        (address owner, , uint8 affinity) = getWizard(wizardId);
        require(msg.sender == owner, "Affinity can only be set by the owner");
        require(affinity == ELEMENT_NOTSET, "Affinity can only be chosen once");

        _wizardsById[wizardId].affinity = newAffinity;

        // Tell the world this wizards now has an affinity!
        emit WizardAlignmentAssigned(wizardId, newAffinity);
    }

    /// @dev An internal convenience function used by conjureWizard and conjureWizardMulti that takes care
    ///      of the work that is shared between them.
    ///      The use of tempElementalWizardCost and updatedElementalWizardCost deserves some explanation here.
    ///      Using elementalWizardCost directly would be very expensive in the case where this function is
    ///      called repeatedly by conjureWizardMulti. Buying an elemental wizard would update the elementalWizardCost
    ///      each time through this function _which would cost 5000 gas each time_. Of course, we don't actually
    ///      need to store the new value each time, only once at the very end. So we go through this very annoying
    ///      process of passing the elementalWizardCost in as an argument (tempElementalWizardCost) and returning
    ///      the updated value as a return value (updatedElementalWizardCost). It's enough to make one want
    ///      tear one's hair out. But! What's done is done, and hopefully SOMEONE will realize how much trouble
    ///      we went to to save them _just that little bit_ of gas cost when they decided to buy a schwack of
    ///      Wizards.
    function _conjureWizard(
        uint256 wizardId,
        address owner,
        uint8 affinity,
        uint256 tempElementalWizardCost) private
        returns (uint256 wizardCost, uint256 updatedElementalWizardCost)
    {
        // Check for a valid elemental affinity
        require(affinity > ELEMENT_NOTSET && affinity <= MAX_ELEMENT, "Non-exclusive Wizards need a real affinity");

        updatedElementalWizardCost = tempElementalWizardCost;

        // Determine the price
        if (affinity == ELEMENT_NEUTRAL) {
            wizardCost = neutralWizardCost;
        } else {
            wizardCost = updatedElementalWizardCost;

            // Update the elemental Wizard cost
            // NOTE: This math can't overflow because the total Ether supply in wei is well less than
            //       2^128. Multiplying a price in wei by some number <100k can't possibly overflow 256 bits.
            updatedElementalWizardCost += (updatedElementalWizardCost * elementalWizardIncrement) / TENTH_BASIS_POINTS;
        }

        // Bring the new Wizard into existence!
        _createWizard(wizardId, owner, costToPower(wizardCost), affinity);
    }

    /// @notice This is it folks, the main event! The way for the world to get new Wizards! Does
    ///         pretty much what it says on the box: Let's you conjure a new Wizard with a specified
    ///         elemental affinity. The call must include enough eth to cover the cost of the new
    ///         Wizard, and any excess is refunded. The power of the Wizard is derived from
    ///         the sale price. YOU CAN NOT PAY EXTRA TO GET MORE POWER. (But you always have the option
    ///         to conjure some more Wizards!) Returns the ID of the newly conjured Wizard.
    /// @param affinity The elemental affinity you want for your wizard.
    function conjureWizard(uint8 affinity) external payable onlyDuringSale returns (uint256 wizardId) {

        wizardId = nextWizardId;
        nextWizardId++;

        uint256 wizardCost;

        (wizardCost, elementalWizardCost) = _conjureWizard(wizardId, msg.sender, affinity, elementalWizardCost);

        require(msg.value >= wizardCost, "Not enough eth to pay");

         // Refund any overpayment
        _transferRefund(wizardCost);

        // Ensure the Wizard is being assigned to an ERC-721 aware address (either an external address,
        // or a smart contract that implements onERC721Reived())
        require(_checkOnERC721Received(address(0), msg.sender, wizardId, ""), "must support erc721");
    }

    /// @notice A convenience function that allows you to get a whole bunch of Wizards at once! You know how
    ///         there's "a pride of lions", "a murder of crows", and "a parliament of owls"? Well, with this
    ///         here function you can conjure yourself "a stench of Cheeze Wizards"!
    /// @dev This function is careful to bundle all of the external calls (the refund and onERC721Received)
    ///         at the end of the function to limit the risk of reentrancy attacks.
    /// @param affinities the elements of the wizards
    function conjureWizardMulti(uint8[] calldata affinities) external payable onlyDuringSale
            returns (uint256[] memory wizardIds)
    {
        // allocate result array
        wizardIds = new uint256[](affinities.length);

        uint256 totalCost = 0;

        // We take these two storage variables, and turn them into local variables for the course
        // of this loop to save about 10k gas per wizard. It's kind of ugly, but that's a lot of
        // gas! Won't somebody please think of the children!!
        uint256 tempWizardId = nextWizardId;
        uint256 tempElementalWizardCost = elementalWizardCost;

        for (uint256 i = 0; i < affinities.length; i++) {
            wizardIds[i] = tempWizardId;
            tempWizardId++;

            uint256 wizardCost;

            (wizardCost, tempElementalWizardCost) = _conjureWizard(
                wizardIds[i],
                msg.sender,
                affinities[i],
                tempElementalWizardCost);

            totalCost += wizardCost;
        }

        elementalWizardCost = tempElementalWizardCost;
        nextWizardId = tempWizardId;

        // check to see if there's enough eth
        require(msg.value >= totalCost, "Not enough eth to pay");

        // Ensure the Wizard is being assigned to an ERC-721 aware address (either an external address,
        // or a smart contract that implements onERC721Received()). We unwind the logic of _checkOnERC721Received
        // because called address.isContract() every time through this loop can get reasonably expensive. We do
        // need to call this function for each token created, however, because it's allowed for an ERC-721 receiving
        // contract to reject the transfer based on the properties of the token.
        if (isContract(msg.sender)) {
            for (uint256 i = 0; i < wizardIds.length; i++) {
                bytes4 retval = IERC721Receiver(msg.sender).onERC721Received(msg.sender, address(0), wizardIds[i], "");
                require(retval == _ERC721_RECEIVED, "Contract owner didn't accept ERC-721 transfer");
            }
        }

        // Refund any excess funds
        _transferRefund(totalCost);
    }

    /// @dev Transfers the current balance to the owner and terminates the contract.
    function destroy() external onlyGuildmaster {
        selfdestruct(guildmaster);
    }
}
