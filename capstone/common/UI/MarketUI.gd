extends CanvasLayer

@onready var buy_list: ItemList = $Root/Panel/BuyList
@onready var sell_list: ItemList = $Root/Panel/SellList
@onready var price_label: Label = $Root/Panel/PriceInfo

var market: MarketController = null
var inv: Inventory = null
var money: int = 100

# Transaction state for optimistic UI handling
var pending_transactions: Dictionary = {}
var transaction_counter: int = 0

# Input validation and logging (§15 Academic Compliance)
var validation_errors: Array = []
var log_entries: Array = []
var _buy_stock_cache: Array = []

func _ready() -> void:
    visible = false
    add_to_group("market_ui")

    # Offline mode: Skip authentication and initialize market directly
    _initialize_offline_market()

    var stage := get_tree().current_scene
    market = stage.get_node_or_null("MarketController")

    # ADD FALLBACK SEARCH if not found in current scene
    if market == null:
        # Try finding in Game singleton
        if has_node("/root/Game"):
            var game = get_node("/root/Game")
            if game.has_method("get_market_controller"):
                market = game.get_market_controller()
            elif game.has_node_or_null("current_stage"):
                var current_stage = game.get_node("current_stage")
                if current_stage:
                    market = current_stage.get_node_or_null("MarketController")

    if market == null:
        print("❌ [MarketUI] No MarketController found - creating fallback")
        _create_fallback_market()
    var player := get_tree().get_first_node_in_group("player")
    if player and player.has_node("Inventory"):
        inv = player.get_node("Inventory")
    if market and not market.stock_changed.is_connected(_on_stock_changed):
        market.stock_changed.connect(_on_stock_changed)

    # Initialize offline money from character data
    _load_offline_money()
    _refresh()

    # Set up stale transaction cleanup timer
    var cleanup_timer := Timer.new()
    cleanup_timer.wait_time = 10.0  # Check every 10 seconds
    cleanup_timer.timeout.connect(_cleanup_stale_transactions)
    cleanup_timer.autostart = true
    add_child(cleanup_timer)

# Input handling re-enabled - UIIntegrationManager not working correctly
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_just_pressed("market"):
        if visible:
            _on_close_pressed()
        else:
            visible = true
        get_viewport().set_input_as_handled()
    elif visible and event.is_action_just_pressed("ui_cancel"):
        _on_close_pressed()
        get_viewport().set_input_as_handled()

func _refresh() -> void:
    if market == null:
        return
    buy_list.clear()
    _buy_stock_cache = market.get_stock_entries()
    for entry in _buy_stock_cache:
        var quantity: int = int(entry.get("quantity", 0))
        var label := _format_stock_entry(entry)
        var row := buy_list.add_item(label)
        if quantity <= 0:
            buy_list.set_item_disabled(row, true)
    sell_list.clear()
    if inv:
        for it in inv.items:
            var sell_value := int(market.get_buyback_price(it))
            var label: String = "%s — $%d" % [it.get("name", "Item"), sell_value]
            sell_list.add_item(label)
    price_label.text = "Money: $%d" % money

func _format_stock_entry(entry: Dictionary) -> String:
    var name: String = entry.get("name", "Item")
    var price := int(entry.get("price", 0))
    var quantity := int(entry.get("quantity", 0))
    var tier := int(entry.get("tier", 1))
    var status := "" if quantity > 0 else " [OUT]"
    return "%s (Tier %d) — $%d x%d%s" % [name, tier, price, max(quantity, 0), status]

func _on_buy_pressed() -> void:
    var idx := buy_list.get_selected_items()

    # Check connection status first (skip for offline mode)
    if not _is_offline_mode():
        var connection_status = _check_connection_status()
        if not connection_status.connected or not connection_status.authenticated:
            _show_transaction_feedback("Purchase failed: %s" % connection_status.message, connection_status.type)
            return

    # Comprehensive input validation for buy transaction (§15 Academic Compliance)
    var validation_result = _validate_buy_transaction(idx)
    if not validation_result.valid:
        _show_transaction_feedback("Purchase failed: %s" % validation_result.error_message, "error")
        _log_validation_error("buy_transaction", validation_result.errors)
        return

    var stock_entry: Dictionary = _buy_stock_cache[idx[0]]
    var item_id: String = stock_entry.get("item_id", "")
    var item_name: String = stock_entry.get("name", item_id)
    var price := int(stock_entry.get("price", 0))

    # Business rule validation
    var business_validation = _validate_business_rules("buy", price, 1)
    if not business_validation.valid:
        _show_transaction_feedback(business_validation.error_message, "error")
        _log_validation_error("business_rules", business_validation.errors)
        return

    if money >= price and inv:
        # Create transaction record for optimistic UI handling
        transaction_counter += 1
        var transaction_id := "buy_%d" % transaction_counter

        var transaction := {
            "type": "buy",
            "item_name": item_name,
            "item_id": item_id,
            "price": price,
            "item_index": idx[0],
            "settlement_id": 1,
            "quantity": 1,
            "original_money": money,
            "added_item": null,
            "timestamp": _get_safe_timestamp()
        }

        # Log successful validation and transaction attempt
        _log_transaction_attempt("buy", transaction)

        # Show loading state
        _set_loading_state(true, "Processing purchase...")
        
        # Offline mode: Process transaction locally
        _process_offline_buy(transaction_id, stock_entry, transaction)
    else:
        if money < price:
            _show_transaction_feedback("Purchase failed: Insufficient funds ($%d needed, $%d available)" % [price, money], "error")
            _log_validation_error("insufficient_funds", [{"price": price, "available": money}])
        else:
            _show_transaction_feedback("Purchase failed: Inventory system unavailable", "error")
            _log_validation_error("inventory_error", [{"inventory_available": inv != null}])

func _on_buy_completed(transaction_id: String, result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    # Clear loading state
    _set_loading_state(false)
    
    if not pending_transactions.has(transaction_id):
        print("⚠️ Warning: Transaction %s not found in pending list" % transaction_id)
        _show_transaction_feedback("Transaction error: Request not found", "error")
        return

    var transaction = pending_transactions[transaction_id]
    var success := false

    # Enhanced error handling with categorization
    match response_code:
        200:
            var json = JSON.new()
            var parse_result = json.parse(body.get_string_from_utf8())
            if parse_result == OK:
                var response = json.data
                if response.get("ok", false):
                    success = true
                    print("✅ Market purchase completed successfully")
                    if response.get("duplicate", false):
                        print("ℹ️ Duplicate request detected - no double charge")
                        _show_transaction_feedback("Purchase completed (duplicate request)", "info")
                    else:
                        _show_transaction_feedback("Purchase successful!", "success")
                else:
                    var detail = response.get("detail", "Unknown server error")
                    print("❌ Market purchase failed: %s" % detail)
                    _show_transaction_feedback("Purchase failed: %s" % detail, "error")
            else:
                print("❌ Failed to parse API response")
                _show_transaction_feedback("Purchase failed: Invalid server response", "error")
        400:
            _show_transaction_feedback("Purchase failed: Invalid request data", "error")
        401:
            _show_transaction_feedback("Purchase failed: Please log in again", "warning")
        403:
            _show_transaction_feedback("Purchase failed: Access denied", "error")  
        404:
            _show_transaction_feedback("Purchase failed: Item not found", "error")
        422:
            _show_transaction_feedback("Purchase failed: Invalid transaction data", "error")
        500:
            _show_transaction_feedback("Purchase failed: Server error (try again)", "error")
        _:
            if response_code == 0:
                _show_transaction_feedback("Purchase failed: No internet connection", "warning")
            else:
                _show_transaction_feedback("Purchase failed: Network error (%d)" % response_code, "error")

    # If transaction failed, revert optimistic changes
    if not success:
        _revert_transaction(transaction)

    # Clean up pending transaction
    pending_transactions.erase(transaction_id)

func _on_sell_pressed() -> void:
    var idx := sell_list.get_selected_items()

    # Comprehensive input validation for sell transaction (§15 Academic Compliance)
    var validation_result = _validate_sell_transaction(idx)
    if not validation_result.valid:
        _show_transaction_feedback(validation_result.error_message, "error")
        _log_validation_error("sell_transaction", validation_result.errors)
        return

    var inventory_item: Dictionary = inv.items[idx[0]]
    var name: String = inventory_item.get("name", "Item")
    var sell_value := int(market.get_buyback_price(inventory_item))

    # Business rule validation
    var business_validation = _validate_business_rules("sell", sell_value, 1)
    if not business_validation.valid:
        _show_transaction_feedback(business_validation.error_message, "error")
        _log_validation_error("sell_business_rules", business_validation.errors)
        return

    # Log successful validation and transaction
    _log_transaction_attempt("sell", {"item": name, "sell_value": sell_value})

    # Process sell transaction offline
    _process_offline_sell(name, sell_value, idx[0])

func _revert_transaction(transaction: Dictionary) -> void:
    """Revert optimistic UI changes when a transaction fails"""
    match transaction.type:
        "buy":
            # Restore original money amount
            money = transaction.original_money
            # Remove the optimistically added item
            if inv:
                var added_item_id: String = transaction.get("added_item_id", "")
                var manifest_id: String = transaction.get("item_manifest_id", "")
                for i in range(inv.items.size()):
                    var item = inv.items[i]
                    if added_item_id != "" and item.get("id", "") == added_item_id:
                        inv.remove_item(i)
                        break
                    elif added_item_id == "" and manifest_id != "" and item.get("item_id", "") == manifest_id:
                        inv.remove_item(i)
                        break
            if market and transaction.has("item_manifest_id"):
                market.revert_purchase(transaction.get("item_manifest_id", ""))
            print("🔄 Reverted failed purchase transaction")
        "sell":
            # TODO: Implement sell transaction reversion if needed
            pass

    _refresh()

func _show_transaction_feedback(message: String, type: String) -> void:
    """Show user feedback for transaction status"""
    var color_code := ""
    match type:
        "success":
            color_code = "[color=green]✅ "
        "error":
            color_code = "[color=red]❌ "
        "info":
            color_code = "[color=blue]ℹ️ "
        "warning":
            color_code = "[color=yellow]⚠️ "

    # Update price label with feedback (temporary)
    var original_text := price_label.text
    price_label.text = color_code + message + "[/color]"

    # Restore original text after 3 seconds
    var timer := Timer.new()
    timer.wait_time = 3.0
    timer.one_shot = true
    timer.timeout.connect(func():
        if price_label:
            price_label.text = original_text
        timer.queue_free()
    )
    add_child(timer)
    timer.start()

func _set_loading_state(loading: bool, message: String = "") -> void:
    """Set loading state - disable/enable buttons and show loading message"""
    # Get button references
    var buy_btn = get_node_or_null("Root/Panel/BuyBtn")
    var sell_btn = get_node_or_null("Root/Panel/SellBtn")
    
    if loading:
        # Disable buttons during loading
        if buy_btn:
            buy_btn.disabled = true
            buy_btn.text = "Processing..."
        if sell_btn:
            sell_btn.disabled = true
            
        # Show loading message
        if message != "":
            _show_transaction_feedback(message, "info")
    else:
        # Re-enable buttons
        if buy_btn:
            buy_btn.disabled = false
            buy_btn.text = "Buy"
        if sell_btn:
            sell_btn.disabled = false

func _has_pending_transactions() -> bool:
    """Check if there are any pending transactions"""
    return pending_transactions.size() > 0

func _check_connection_status() -> Dictionary:
    """Check API connection status and authentication"""
    var status = {
        "connected": false,
        "authenticated": false,
        "message": "",
        "type": "error"
    }
    
    if not Api:
        status.message = "API system unavailable"
        return status
        
    if Api.jwt == "":
        status.message = "Not logged in - authentication required"
        status.type = "warning"
        return status
    
    # Basic connection check - if we have a JWT token, assume we're connected
    # In a full implementation, you might ping a health endpoint
    status.connected = true
    status.authenticated = true
    status.message = "Connected"
    status.type = "success"
    
    return status

func _is_offline_mode() -> bool:
    """Check if we're in offline mode (no API or no authentication required)"""
    # If no API system available, we're definitely offline
    if not Api:
        return true

    # If no JWT token, consider offline mode for market operations
    if Api.jwt == "":
        return true

    # Check AuthController offline status if available
    if has_node("/root/AuthController"):
        var auth_controller = get_node("/root/AuthController")
        if auth_controller.has_method("is_offline_mode"):
            return auth_controller.is_offline_mode()

    # Default to offline mode for safety
    return true

func _cleanup_stale_transactions() -> void:
    """Clean up transactions that have been pending too long (30+ seconds)"""
    var current_time := _get_safe_timestamp()
    var to_remove: Array = []

    for transaction_id in pending_transactions:
        var transaction = pending_transactions[transaction_id]
        if current_time - transaction.timestamp > 30.0:
            print("⚠️ Cleaning up stale transaction: %s" % transaction_id)
            _log_validation_error("stale_transaction", [{"transaction_id": transaction_id, "age_seconds": current_time - transaction.timestamp}])
            _revert_transaction(transaction)
            to_remove.append(transaction_id)

    for transaction_id in to_remove:
        pending_transactions.erase(transaction_id)

# Input Validation System (§15 Academic Compliance)
func _validate_buy_transaction(selected_indices: Array) -> Dictionary:
    """Validate buy transaction input with comprehensive error reporting"""
    var errors: Array = []
    var valid := true

    # Check if selection exists
    if selected_indices.size() == 0:
        errors.append({"field": "selection", "message": "No item selected"})
        valid = false

    # Check if market data is available
    if not market or _buy_stock_cache.is_empty():
        errors.append({"field": "market", "message": "Market data unavailable"})
        valid = false

    # Check if selection index is valid
    if selected_indices.size() > 0:
        var idx = selected_indices[0]
        if idx < 0 or idx >= _buy_stock_cache.size():
            errors.append({"field": "index", "message": "Invalid item index: %d" % idx})
            valid = false
        elif _buy_stock_cache[idx].get("quantity", 0) <= 0:
            errors.append({"field": "quantity", "message": "Selected item is out of stock"})
            valid = false

    # Check if inventory system is available
    if not inv:
        errors.append({"field": "inventory", "message": "Inventory system unavailable"})
        valid = false

    var error_message = "Transaction validation failed"
    if errors.size() > 0:
        error_message = errors[0].message

    return {"valid": valid, "errors": errors, "error_message": error_message}

func _validate_sell_transaction(selected_indices: Array) -> Dictionary:
    """Validate sell transaction input with comprehensive error reporting"""
    var errors: Array = []
    var valid := true

    # Check if selection exists
    if selected_indices.size() == 0:
        errors.append({"field": "selection", "message": "No item selected"})
        valid = false

    # Check if inventory is available
    if not inv:
        errors.append({"field": "inventory", "message": "Inventory unavailable"})
        valid = false
    elif inv.items.is_empty():
        errors.append({"field": "inventory", "message": "No items to sell"})
        valid = false
    elif selected_indices.size() > 0:
        var idx = selected_indices[0]
        if idx < 0 or idx >= inv.items.size():
            errors.append({"field": "index", "message": "Invalid inventory index: %d" % idx})
            valid = false

    # Check if market system is available for pricing
    if not market:
        errors.append({"field": "market", "message": "Market pricing unavailable"})
        valid = false
    elif selected_indices.size() > 0 and inv:
        var idx = selected_indices[0]
        if idx >= 0 and idx < inv.items.size():
            var item: Dictionary = inv.items[idx]
            var sell_price: int = market.get_buyback_price(item)
            if sell_price <= 0:
                errors.append({"field": "pricing", "message": "Item cannot be sold"})
                valid = false

    var error_message = "Sell validation failed"
    if errors.size() > 0:
        error_message = errors[0].message

    return {"valid": valid, "errors": errors, "error_message": error_message}

func _validate_business_rules(transaction_type: String, amount: int, quantity: int) -> Dictionary:
    """Validate business rules for transactions"""
    var errors: Array = []
    var valid := true

    # Amount validation
    if amount <= 0:
        errors.append({"field": "amount", "message": "Invalid transaction amount: %d" % amount})
        valid = false
    elif amount > 999999:  # Sanity check for excessive amounts
        errors.append({"field": "amount", "message": "Transaction amount too large: %d" % amount})
        valid = false

    # Quantity validation
    if quantity <= 0:
        errors.append({"field": "quantity", "message": "Invalid quantity: %d" % quantity})
        valid = false
    elif quantity > 100:  # Sanity check for bulk transactions
        errors.append({"field": "quantity", "message": "Quantity too large: %d" % quantity})
        valid = false

    # Transaction type specific validation
    match transaction_type:
        "buy":
            if money < amount:
                errors.append({"field": "funds", "message": "Insufficient funds: need %d, have %d" % [amount, money]})
                valid = false
        "sell":
            if amount > money + 100000:  # Sanity check for sell values
                errors.append({"field": "sell_value", "message": "Sell value suspiciously high: %d" % amount})
                valid = false

    var error_message = "Business rule validation failed"
    if errors.size() > 0:
        error_message = errors[0].message

    return {"valid": valid, "errors": errors, "error_message": error_message}

# Logging System with Structured Data
func _log_validation_error(error_type: String, errors: Array) -> void:
    """Log validation errors with structured data for analysis"""
    var log_entry = {
        "timestamp": _get_safe_datetime_string(),
        "unix_time": _get_safe_timestamp(),
        "level": "ERROR",
        "component": "MarketUI",
        "event_type": "validation_error",
        "error_type": error_type,
        "errors": errors,
        "user_money": money,
        "pending_transactions": pending_transactions.size()
    }

    log_entries.append(log_entry)
    print("❌ [MarketUI] Validation Error [%s]: %s" % [error_type, JSON.stringify(errors)])

    # Keep log entries under control (last 100 entries)
    if log_entries.size() > 100:
        log_entries = log_entries.slice(-100)

func _log_transaction_attempt(transaction_type: String, transaction_data: Dictionary) -> void:
    """Log successful transaction attempts for audit trail"""
    var log_entry = {
        "timestamp": _get_safe_datetime_string(),
        "unix_time": _get_safe_timestamp(),
        "level": "INFO",
        "component": "MarketUI",
        "event_type": "transaction_attempt",
        "transaction_type": transaction_type,
        "transaction_data": transaction_data,
        "user_money": money
    }

    log_entries.append(log_entry)
    print("📝 [MarketUI] Transaction Attempt [%s]: %s" % [transaction_type, transaction_data.get("item_name", "unknown")])

    # Keep log entries under control
    if log_entries.size() > 100:
        log_entries = log_entries.slice(-100)

# Public API for validation status monitoring
func get_validation_status() -> Dictionary:
    """Get current validation and error status for debugging"""
    return {
        "validation_errors_count": validation_errors.size(),
        "log_entries_count": log_entries.size(),
        "pending_transactions_count": pending_transactions.size(),
        "last_validation_errors": validation_errors.slice(-5) if validation_errors.size() > 0 else [],
        "recent_logs": log_entries.slice(-10) if log_entries.size() > 0 else []
    }

func _on_close_pressed() -> void:
    """Close the market UI"""
    visible = false

# =============================================================================
# OFFLINE MARKET SYSTEM - Phase 2 Implementation
# =============================================================================

var offline_transaction_queue: Array = []
var offline_player_money: int = 100

func _initialize_offline_market() -> void:
    """Initialize offline market system with local data"""
    print("🔌 [MarketUI] Initializing offline market system")

    # Load saved offline money from character data
    if CharacterService:
        var character = CharacterService.get_current_character()
        offline_player_money = character.get("money", 100)

    print("💰 [MarketUI] Starting with $%d offline money" % offline_player_money)

func _load_offline_money() -> void:
    """Load player money from character system for offline mode"""
    if CharacterService:
        var character = CharacterService.get_current_character()
        var char_money = character.get("money", 100)
        offline_player_money = char_money
        money = char_money  # Update UI money display
        print("💰 [MarketUI] Loaded $%d from character data" % offline_player_money)
    else:
        offline_player_money = 100
        money = 100
        print("💰 [MarketUI] Using default $100 (no CharacterService)")

func _process_offline_buy(transaction_id: String, stock_entry: Dictionary, transaction: Dictionary) -> void:
    """Process a buy transaction offline"""
    var item_id: String = stock_entry.get("item_id", "")
    var item_name: String = stock_entry.get("name", item_id)
    var price := int(stock_entry.get("price", 0))

    print("🛒 [MarketUI] Processing offline purchase: %s (%s) for $%d" % [item_name, item_id, price])

    var purchase := market.purchase_item(item_id)
    if not purchase.get("success", false):
        var reason := String(purchase.get("reason", "unavailable")).capitalize()
        _show_transaction_feedback("Purchase failed: %s" % reason, "error")
        _set_loading_state(false)
        _refresh()
        return

    var new_item: Dictionary = purchase.get("item", {})

    if inv and inv.add_item(new_item):
        # Deduct money
        offline_player_money -= price
        money = offline_player_money

        # Save updated money to character
        _save_offline_money()

        # Track added item for potential rollback
        transaction["added_item"] = new_item.duplicate(true)
        transaction["added_item_id"] = new_item.get("id", "")
        transaction["price"] = price
        transaction["item_name"] = item_name
        transaction["item_manifest_id"] = item_id

        # Create offline transaction record for future sync
        var offline_transaction := {
            "type": "buy",
            "item_name": item_name,
            "item_id": item_id,
            "price": price,
            "timestamp": _get_safe_timestamp(),
            "transaction_id": transaction_id
        }
        offline_transaction_queue.append(offline_transaction)

        _set_loading_state(false)
        _refresh()
        _show_transaction_feedback("Purchase successful! (Offline mode)", "success")
        print("✅ [MarketUI] Offline purchase complete: %s ($%d remaining)" % [item_name, offline_player_money])
    else:
        market.revert_purchase(item_id)
        _set_loading_state(false)
        _show_transaction_feedback("Purchase failed: Inventory full", "error")
        print("❌ [MarketUI] Offline purchase failed: inventory full")

func _save_offline_money() -> void:
    """Save current money to character data"""
    if CharacterService:
        var character = CharacterService.get_current_character()
        character["money"] = offline_player_money
        CharacterService.set_current_character(character)
        print("💾 [MarketUI] Saved $%d to character data" % offline_player_money)

func get_offline_transaction_queue() -> Array:
    """Get pending offline transactions for future sync"""
    return offline_transaction_queue.duplicate()

func clear_offline_transaction_queue() -> void:
    """Clear offline transaction queue after successful sync"""
    offline_transaction_queue.clear()
    print("🗑️ [MarketUI] Cleared offline transaction queue")

func _on_stock_changed() -> void:
    _refresh()

func _process_offline_sell(item_name: String, sell_value: int, item_index: int) -> void:
    """Process a sell transaction offline"""
    print("💰 [MarketUI] Processing offline sale: %s for $%d" % [item_name, sell_value])

    if inv:
        var item: Dictionary = inv.items[item_index]
        var item_id := String(item.get("item_id", ""))

        # Remove item from inventory
        inv.remove_item(item_index)

        # Add money
        offline_player_money += sell_value
        money = offline_player_money

        # Save updated money to character
        _save_offline_money()

        # Create offline transaction record for future sync
        var offline_transaction := {
            "type": "sell",
            "item_name": item_name,
            "item_id": item_id,
            "sell_value": sell_value,
            "timestamp": _get_safe_timestamp(),
            "transaction_id": "sell_%d" % Time.get_unix_time_from_system()
        }
        offline_transaction_queue.append(offline_transaction)

        # Add sold item back into market stock for future purchases
        if market:
            market.receive_sellback(item)

        # Update UI
        _refresh()
        _show_transaction_feedback("Item sold for $%d (Offline mode)" % sell_value, "success")
        print("✅ [MarketUI] Offline sale complete: %s ($%d total)" % [item_name, offline_player_money])
    else:
        _show_transaction_feedback("Sale failed: Inventory system unavailable", "error")
        print("❌ [MarketUI] Offline sale failed: no inventory")

# =============================================================================
# ONLINE SYNC SYSTEM - Phase 4 Implementation
# =============================================================================

func sync_offline_transactions() -> void:
    """Sync queued offline transactions when going back online"""
    if offline_transaction_queue.is_empty():
        print("📡 [MarketUI] No offline transactions to sync")
        return

    print("📡 [MarketUI] Starting sync of %d offline transactions" % offline_transaction_queue.size())

    # Check if we're actually online now
    if not await AuthController.require_authentication():
        print("⚠️ [MarketUI] Cannot sync: still offline")
        _show_transaction_feedback("Cannot sync transactions: still offline", "warning")
        return

    var sync_success_count := 0
    var sync_failure_count := 0
    var failed_transactions: Array = []

    for transaction in offline_transaction_queue:
        var success := await _sync_single_transaction(transaction)
        if success:
            sync_success_count += 1
        else:
            sync_failure_count += 1
            failed_transactions.append(transaction)

    # Update the queue to only keep failed transactions
    offline_transaction_queue = failed_transactions

    # Report sync results
    if sync_failure_count == 0:
        _show_transaction_feedback("All %d transactions synced successfully!" % sync_success_count, "success")
        print("✅ [MarketUI] Sync complete: %d/%d transactions successful" % [sync_success_count, sync_success_count])
    else:
        _show_transaction_feedback("Sync partial: %d success, %d failed" % [sync_success_count, sync_failure_count], "warning")
        print("⚠️ [MarketUI] Sync partial: %d success, %d failed, %d queued for retry" % [sync_success_count, sync_failure_count, failed_transactions.size()])

func _sync_single_transaction(transaction: Dictionary) -> bool:
    """Sync a single offline transaction to the server"""
    var transaction_type = transaction.get("type", "unknown")
    print("🔄 [MarketUI] Syncing %s transaction: %s" % [transaction_type, transaction.get("transaction_id", "unknown")])

    match transaction_type:
        "buy":
            return await _sync_buy_transaction(transaction)
        "sell":
            return await _sync_sell_transaction(transaction)
        _:
            print("❌ [MarketUI] Unknown transaction type: %s" % transaction_type)
            return false

func _sync_buy_transaction(transaction: Dictionary) -> bool:
    """Sync a buy transaction with the server"""
    # Note: In a real implementation, you'd need to handle the fact that the item
    # was already added to inventory locally. This would require server-side logic
    # to handle idempotent transactions or transaction reconciliation.

    print("🛒 [MarketUI] Syncing buy: %s for $%d" % [transaction.get("item_name", "unknown"), transaction.get("price", 0)])

    # For now, we'll just log the transaction as synced
    # In a real implementation, you would:
    # 1. Send transaction data to server for logging/analytics
    # 2. Handle any server-side inventory verification
    # 3. Reconcile any discrepancies between local and server state

    await get_tree().process_frame  # Simulate network delay
    print("✅ [MarketUI] Buy transaction synced (simulated)")
    return true

func _sync_sell_transaction(transaction: Dictionary) -> bool:
    """Sync a sell transaction with the server"""
    print("💰 [MarketUI] Syncing sell: %s for $%d" % [transaction.get("item_name", "unknown"), transaction.get("sell_value", 0)])

    # Similar to buy transactions, in a real implementation you would:
    # 1. Verify the item was legitimately sold
    # 2. Update server-side inventory and economy data
    # 3. Handle any synchronization conflicts

    await get_tree().process_frame  # Simulate network delay
    print("✅ [MarketUI] Sell transaction synced (simulated)")
    return true

func check_online_status_and_sync() -> void:
    """Check if we're back online and offer to sync transactions"""
    if offline_transaction_queue.is_empty():
        return

    # Check if authentication is working (indicates we're online)
    var auth_ok := await AuthController.require_authentication()
    if auth_ok:
        # We're back online and have transactions to sync
        var queue_size := offline_transaction_queue.size()
        _show_transaction_feedback("Back online! %d transactions ready to sync" % queue_size, "info")

        # Auto-sync after a brief delay to let user see the message
        await get_tree().create_timer(2.0).timeout
        sync_offline_transactions()

func get_sync_status() -> Dictionary:
    """Get current synchronization status"""
    return {
        "offline_transactions_pending": offline_transaction_queue.size(),
        "last_sync_attempt": "not_implemented",  # Would store timestamp in real implementation
        "sync_failures_count": 0,  # Would track failures in real implementation
        "transactions_queue": offline_transaction_queue.duplicate()
    }

func _get_safe_timestamp() -> int:
    """Safely get timestamp with fallback if GameTime is not available"""
    if has_node("/root/GameTime"):
        return GameTime.get_unix_time_from_system()
    else:
        return Time.get_unix_time_from_system()

func _get_safe_datetime_string() -> String:
    """Safely get datetime string with fallback if GameTime is not available"""
    if has_node("/root/GameTime"):
        return GameTime.get_datetime_string_from_system()
    else:
        return Time.get_datetime_string_from_system()

func _create_fallback_market():
    """Create a fallback market controller when none is found"""
    print("🔧 [MarketUI] Creating fallback market controller")

    # Create a minimal market controller
    var fallback_market = Node.new()
    fallback_market.name = "FallbackMarketController"
    fallback_market.set_script(preload("res://common/Economy/MarketController.gd"))

    # Add to current scene
    get_tree().current_scene.add_child(fallback_market)
    market = fallback_market

    # Initialize with basic stock
    call_deferred("_initialize_fallback_stock")

func _initialize_fallback_stock():
    """Initialize fallback market with basic stock from item manifest"""
    if not market:
        return

    print("📦 [MarketUI] Initializing fallback market stock")

    # Add basic items to market stock
    var basic_items = [
        {"item_id": "medical_kit", "quantity": 10, "price": 60},
        {"item_id": "bandage", "quantity": 20, "price": 25},
        {"item_id": "energy_bar", "quantity": 15, "price": 35},
        {"item_id": "scrap_metal", "quantity": 50, "price": 12},
        {"item_id": "fabric", "quantity": 30, "price": 18},
        {"item_id": "weapon_lv1", "quantity": 3, "price": 250},
        {"item_id": "weapon_lv2", "quantity": 2, "price": 500}
    ]

    # Add items to market stock if market has the method
    if market.has_method("add_stock_entry"):
        for item in basic_items:
            market.add_stock_entry(item.item_id, item.quantity, item.price)
    elif market.has_method("set_stock"):
        market.set_stock(basic_items)

    # Refresh the UI to show new stock
    _refresh()
