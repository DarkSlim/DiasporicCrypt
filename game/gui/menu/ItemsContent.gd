
extends "res://gui/menu/MenuContent.gd"

# display currently collected items

var info
var itemclass = preload("res://gui/menu/inventoryitem.scn")
var itemcontainer
var tab
var currenttype = "item"
var selecteditem
var echo = false
var use
var drop

func _ready():
	has_content = true
	info = get_node("info")
	info.hide()
	use = info.get_node("use")
	drop = info.get_node("drop")
	itemcontainer = get_node("itemcontainer/VBoxContainer")

func update_container():
	var list = Globals.get("inventory").generate_list(currenttype)
	for item in list:
		if (!itemcontainer.has_node(item["item"].title)):
			var item_obj = itemclass.instance()
			item_obj.set_name(item["item"].title)
			item_obj.get_node("title").set_text(item["item"].title)
			item_obj.get_node("quantity").set_text(str(item["quantity"]))
			if (!item["item"].new):
				item_obj.get_node("new").hide()
			# don't lose focus on irrelevant inputs
			item_obj.set_focus_neighbour(MARGIN_LEFT, ".")
			item_obj.set_focus_neighbour(MARGIN_RIGHT, ".")
			item_obj.set_focus_neighbour(MARGIN_BOTTOM, ".")
			item_obj.connect("focus_enter", self, "focus_item_enter")
			item_obj.connect("focus_exit", self, "focus_item_exit")
			# previous item should focus the next item properly
			if (itemcontainer.get_child_count() > 0):
				var lastitem = itemcontainer.get_child(itemcontainer.get_child_count() - 1)
				lastitem.set_focus_neighbour(MARGIN_BOTTOM, "")
			itemcontainer.add_child(item_obj)
		else:
			itemcontainer.get_node(item["item"].title + "/quantity").set_text(str(item["quantity"]))
	if (itemcontainer.get_child_count() > 0):
		get_node("noitems").hide()
	else:
		get_node("noitems").show()

func clear_items():
	for i in itemcontainer.get_children():
		itemcontainer.remove_child(i)
		i.queue_free()

func unfocus_all():
	for item in itemcontainer.get_children():
		item.release_focus()
	for item in get_node("types").get_children():
		item.release_focus()
	currenttype = "item"
	use.set_opacity(0.5)
	drop.set_opacity(0.5)
	use.release_focus()
	drop.release_focus()
	info.hide()
	selecteditem = null

func change_type():
	if (get_focus_owner() != null && get_focus_owner().get_name() != currenttype):
		set_type(get_focus_owner().get_name())

func set_type(value):
	currenttype = value
	clear_items()
	update_container()
	info.hide()
	if (currenttype == "special"):
		use.hide()
		drop.hide()
	else:
		use.show()
		drop.show()

func focus_item_enter():
	info.show()
	use.set_opacity(0.5)
	drop.set_opacity(0.5)
	set_process_input(true)
	var scrollcontainer = get_node("itemcontainer")
	var item = get_focus_owner()
	var inventory = Globals.get("inventory").inventory
	var item_obj = inventory[item.get_name()]["item"]
	item_obj.new = false
	inventory[item_obj.title]["item"] = item_obj
	item.get_node("new").hide()
	info.get_node("image").set_texture(load(item_obj.image))
	info.get_node("title").set_text(item_obj.title)
	info.get_node("description").set_bbcode(tr(item_obj.description))
	if (scrollcontainer.get_v_scroll() + scrollcontainer.get_size().y < item.get_pos().y + item.get_size().y || scrollcontainer.get_v_scroll() > item.get_pos().y):
		scrollcontainer.set_v_scroll(item.get_pos().y)

func focus_item_exit():
	info.hide()
	set_process_input(false)

func block_cancel():
	# use/drop are already unfocused, so check echo flag instead
	var result = item_selected() || echo
	echo = false
	return result

func item_selected():
	return get_focus_owner() == info.get_node("use") || get_focus_owner() == info.get_node("drop")

func _input(event):
	if (event.is_pressed() && !event.is_echo()):
		var type = get_node("types/" + currenttype)
		var newtype
		if (event.is_action_pressed("ui_left") && selecteditem == null && type.get_index() > 0):
			newtype = get_node("types").get_child(type.get_index() - 1)
			set_type(newtype.get_name())
			newtype.grab_focus()
		if (event.is_action_pressed("ui_right") && selecteditem == null && type.get_index() < get_node("types").get_child_count() - 1):
			newtype = get_node("types").get_child(type.get_index() + 1)
			set_type(newtype.get_name())
			newtype.grab_focus()
		if (event.is_action_pressed("ui_accept") && info.is_visible() && currenttype != "special"):
			var focus = get_focus_owner()
			var inventory = Globals.get("inventory")
			# update container and item when using or dropping them
			# return back to item selection if no selected items left
			if (focus.get_name() == use.get_name()):
				var item = inventory.get("inventory")[selecteditem.get_name()]["item"]
				var quantity = inventory.use_item(item)
				update_container()
				if (quantity == 0):
					clear_selection(item)
				else:
					check_item(item)
					selecteditem = itemcontainer.get_node(item.title)
			elif (focus.get_name() == drop.get_name()):
				var item = inventory.get("inventory")[selecteditem.get_name()]["item"]
				var quantity = inventory.remove_item(item, 1)
				update_container()
				if (quantity == 0):
					clear_selection(item)
				else:
					selecteditem = itemcontainer.get_node(item.title)
			else:
				# no items selected, select current item instead
				var item = inventory.get("inventory")[focus.get_name()]["item"]
				selecteditem = focus
				check_item(item)
				info.show()
				set_process_input(true)
		if (event.is_action_pressed("ui_cancel") && item_selected()):
			# go back to item selection
			selecteditem.grab_focus()
			use.set_opacity(0.5)
			drop.set_opacity(0.5)
			echo = true
			selecteditem = null

func clear_selection(item):
	if (itemcontainer.has_node(item.title)):
		var item_obj = itemcontainer.get_node(item.title)
		itemcontainer.remove_child(item_obj)
		item_obj.queue_free()
	var type = currenttype
	unfocus_all()
	currenttype = type
	if (itemcontainer.get_child_count() > 0):
		itemcontainer.get_child(0).grab_focus()
	else:
		get_node("types/" + currenttype).grab_focus()

func check_item(item):
	if (Globals.get("inventory").check_usable(item)):
		use.set_opacity(1)
		use.grab_focus()
		drop.set_focus_neighbour(MARGIN_TOP, use.get_path())
	else:
		use.set_opacity(0.5)
		drop.grab_focus()
		drop.set_focus_neighbour(MARGIN_TOP, ".")
	drop.set_opacity(1)