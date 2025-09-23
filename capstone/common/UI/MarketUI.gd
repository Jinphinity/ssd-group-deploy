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

func _ready() -> void:
    visible = false

    # Check authentication before allowing market access
    if not AuthController.require_authentication():
        _show_transaction_feedback("Authentication required for market access", "error")
        return

    var stage := get_tree().current_scene
    market = stage.get_node_or_null("MarketController")
    var player := get_tree().get_first_node_in_group("player")
    if player and player.has_node("Inventory"):
        inv = player.get_node("Inventory")
    _refresh()

    # Set up stale transaction cleanup timer
    var cleanup_timer := Timer.new()
    cleanup_timer.wait_time = 10.0  # Check every 10 seconds
    cleanup_timer.timeout.connect(_cleanup_stale_transactions)
    cleanup_timer.autostart = true
    add_child(cleanup_timer)

func _refresh() -> void:
    if market == null:
        return
    buy_list.clear()
    for k in market.current_prices.keys():
        buy_list.add_item("%s — $%d" % [k, int(market.current_prices[k])])
    sell_list.clear()
    if inv:
        for it in inv.items:
            sell_list.add_item("%s" % it.get("name", "Item"))
    price_label.text = "Money: $%d" % money

func _on_buy_pressed() -> void:
    var idx := buy_list.get_selected_items()

    # Comprehensive input validation for buy transaction (§15 Academic Compliance)
    var validation_result = _validate_buy_transaction(idx)
    if not validation_result.valid:
        _show_transaction_feedback(validation_result.error_message, "error")
        _log_validation_error("buy_transaction", validation_result.errors)
        return

    var item_name := market.current_prices.keys()[idx[0]]
    var price := int(market.current_prices[item_name])

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
            "price": price,
            "item_id": idx[0] + 1,
            "settlement_id": 1,
            "quantity": 1,
            "original_money": money,
            "added_item": null,
            "timestamp": Time.get_unix_time_from_system()
        }

        # Log successful validation and transaction attempt
        _log_transaction_attempt("buy", transaction)

        # Use API for server-authoritative market transaction
        var req := Api.market_buy(1, idx[0] + 1, 1)  # settlement_id=1, item_id based on index, quantity=1
        req.request_completed.connect(_on_buy_completed.bind(transaction_id))

        # Optimistically update UI (will be corrected if API fails)
        var new_item := {"name": item_name, "slot_size": 1, "weight": 1.0, "durability": 100}
        if inv.add_item(new_item):
            transaction.added_item = new_item
            money -= price
            pending_transactions[transaction_id] = transaction
            _refresh()
            _show_transaction_feedback("Processing purchase...", "info")
        else:
            _show_transaction_feedback("Inventory full!", "error")
    else:
        if money < price:
            _show_transaction_feedback("Cannot afford this item!", "error")
            _log_validation_error("insufficient_funds", [{"price": price, "available": money}])
        else:
            _show_transaction_feedback("Inventory unavailable!", "error")
            _log_validation_error("inventory_error", [{"inventory_available": inv != null}])

func _on_buy_completed(transaction_id: String, result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    if not pending_transactions.has(transaction_id):
        print("⚠️ Warning: Transaction %s not found in pending list" % transaction_id)
        return

    var transaction = pending_transactions[transaction_id]
    var success := false

    if response_code == 200:
        var json = JSON.new()
        var parse_result = json.parse(body.get_string_from_utf8())
        if parse_result == OK:
            var response = json.data
            if response.get("ok", false):
                success = true
                print("✅ Market purchase completed successfully")
                _show_transaction_feedback("Purchase successful!", "success")
                if response.get("duplicate", false):
                    print("ℹ️ Duplicate request detected - no double charge")
                    _show_transaction_feedback("Duplicate request - no charge", "info")
            else:
                print("❌ Market purchase failed: %s" % response.get("detail", "Unknown error"))
                _show_transaction_feedback("Purchase failed: %s" % response.get("detail", "Server error"), "error")
        else:
            print("❌ Failed to parse API response")
            _show_transaction_feedback("Purchase failed: Invalid response", "error")
    else:
        print("❌ API call failed with code: ", response_code)
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

    var name := inv.items[idx[0]].get("name", "Item")
    var price := int(market.current_prices.get(name, 10))
    var sell_value := int(price * 0.5)

    # Business rule validation
    var business_validation = _validate_business_rules("sell", sell_value, 1)
    if not business_validation.valid:
        _show_transaction_feedback(business_validation.error_message, "error")
        _log_validation_error("sell_business_rules", business_validation.errors)
        return

    # Log successful validation and transaction
    _log_transaction_attempt("sell", {"item": name, "sell_value": sell_value})

    inv.remove_item(idx[0])
    money += sell_value
    _refresh()
    _show_transaction_feedback("Item sold for $%d" % sell_value, "success")

func _revert_transaction(transaction: Dictionary) -> void:
    """Revert optimistic UI changes when a transaction fails"""
    match transaction.type:
        "buy":
            # Restore original money amount
            money = transaction.original_money
            # Remove the optimistically added item
            if transaction.added_item and inv:
                var item_to_remove = transaction.added_item
                for i in range(inv.items.size()):
                    var item = inv.items[i]
                    if (item.get("name") == item_to_remove.get("name") and
                        item.get("durability") == item_to_remove.get("durability")):
                        inv.remove_item(i)
                        break
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

func _has_pending_transactions() -> bool:
    """Check if there are any pending transactions"""
    return pending_transactions.size() > 0

func _cleanup_stale_transactions() -> void:
    """Clean up transactions that have been pending too long (30+ seconds)"""
    var current_time := Time.get_unix_time_from_system()
    var to_remove := []

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
    var errors := []
    var valid := true

    # Check if selection exists
    if selected_indices.size() == 0:
        errors.append({"field": "selection", "message": "No item selected"})
        valid = false

    # Check if market data is available
    if not market or market.current_prices.is_empty():
        errors.append({"field": "market", "message": "Market data unavailable"})
        valid = false

    # Check if selection index is valid
    if selected_indices.size() > 0:
        var idx = selected_indices[0]
        if idx < 0 or idx >= market.current_prices.keys().size():
            errors.append({"field": "index", "message": "Invalid item index: %d" % idx})
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
    var errors := []
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
    if not market or market.current_prices.is_empty():
        errors.append({"field": "market", "message": "Market pricing unavailable"})
        valid = false

    var error_message = "Sell validation failed"
    if errors.size() > 0:
        error_message = errors[0].message

    return {"valid": valid, "errors": errors, "error_message": error_message}

func _validate_business_rules(transaction_type: String, amount: int, quantity: int) -> Dictionary:
    """Validate business rules for transactions"""
    var errors := []
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
        "timestamp": Time.get_datetime_string_from_system(),
        "unix_time": Time.get_unix_time_from_system(),
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
        "timestamp": Time.get_datetime_string_from_system(),
        "unix_time": Time.get_unix_time_from_system(),
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
        "last_validation_errors": validation_errors.size() > 0 ? validation_errors.slice(-5) : [],
        "recent_logs": log_entries.size() > 0 ? log_entries.slice(-10) : []
    }
