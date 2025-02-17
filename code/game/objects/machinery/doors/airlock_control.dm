#define AIRLOCK_CONTROL_RANGE 22

// This code allows for airlocks to be controlled externally by setting an id_tag and comm frequency (disables ID access)
/obj/machinery/door/airlock
	var/id_tag
	var/frequency
	var/shockedby = list()
	var/datum/radio_frequency/radio_connection
	var/cur_command = null	//the command the door is currently attempting to complete

/obj/machinery/door/airlock/proc/can_radio()
	return hasPower()

/obj/machinery/door/airlock/receive_signal(datum/signal/signal)
	if(!hasPower())
		return

	if (!can_radio()) return //no radio

	if(!signal)
		return

	if(id_tag != signal.data["tag"] || !signal.data["command"]) return

	cur_command = signal.data["command"]
	INVOKE_ASYNC(src, .proc/execute_current_command)

/obj/machinery/door/airlock/proc/execute_current_command()
	if(operating)
		return

	if (!cur_command)
		return

	do_command(cur_command)
	if (command_completed(cur_command))
		cur_command = null

/obj/machinery/door/airlock/proc/do_command(command)
	switch(command)
		if("open")
			open()

		if("close")
			close()

		if("unlock")
			unlock()

		if("lock")
			lock()

		if("secure_open")
			unlock()

			sleep(2)
			open()

			lock()

		if("secure_close")
			unlock()
			close()

			lock()
			sleep(2)

	send_status()

/obj/machinery/door/airlock/proc/command_completed(command)
	switch(command)
		if("open")
			return (!density)

		if("close")
			return density

		if("unlock")
			return !locked

		if("lock")
			return locked

		if("secure_open")
			return (locked && !density)

		if("secure_close")
			return (locked && density)

	return 1	//Unknown command. Just assume it's completed.

/obj/machinery/door/airlock/proc/send_status(bumped = FALSE)
	if(radio_connection)
		var/datum/signal/signal = new
		signal.transmission_method = 1 //radio signal
		signal.data["tag"] = id_tag
		signal.data["timestamp"] = world.time

		signal.data["door_status"] = density?("closed"):("open")
		signal.data["lock_status"] = locked?("locked"):("unlocked")

		if (bumped)
			signal.data["bumped_with_access"] = 1

		radio_connection.post_signal(src, signal, range = AIRLOCK_CONTROL_RANGE, filter = RADIO_AIRLOCK)

/obj/machinery/door/airlock/proc/set_frequency(new_frequency)
	SSradio.remove_object(src, frequency)
	if(new_frequency)
		frequency = new_frequency
		radio_connection = SSradio.add_object(src, frequency, RADIO_AIRLOCK)


/obj/machinery/door/airlock/Initialize()
	. = ..()
	if(frequency)
		set_frequency(frequency)
	update_icon()

/obj/machinery/airlock_sensor
	icon = 'icons/obj/airlock_machines.dmi'
	icon_state = "airlock_sensor_off"
	name = "airlock sensor"

	anchored = TRUE
	power_channel = ENVIRON

	var/id_tag
	var/master_tag
	var/frequency = 1379
	var/command = "cycle"

	var/datum/radio_frequency/radio_connection

	var/on = 1
	var/alert = 0
	var/previousPressure

/obj/machinery/airlock_sensor/update_icon_state()
	if(on)
		icon_state = "airlock_sensor_off"
		return
	if(alert)
		icon_state = "airlock_sensor_alert"
	else
		icon_state = "airlock_sensor_standby"


/obj/machinery/airlock_sensor/attack_hand(mob/living/user)
	. = ..()
	if(.)
		return
	var/datum/signal/signal = new
	signal.transmission_method = 1 //radio signal
	signal.data["tag"] = master_tag
	signal.data["command"] = command

	radio_connection.post_signal(src, signal, range = AIRLOCK_CONTROL_RANGE, filter = RADIO_AIRLOCK)
	flick("airlock_sensor_cycle", src)

/obj/machinery/airlock_sensor/process()
	if(on)
		var/air_pressure = return_air()
		var/pressure = round(air_pressure,0.1)

		if(abs(pressure - previousPressure) > 0.001 || previousPressure == null)
			var/datum/signal/signal = new
			signal.transmission_method = 1 //radio signal
			signal.data["tag"] = id_tag
			signal.data["timestamp"] = world.time
			signal.data["pressure"] = num2text(pressure)

			radio_connection.post_signal(src, signal, range = AIRLOCK_CONTROL_RANGE, filter = RADIO_AIRLOCK)

			previousPressure = pressure

			alert = (pressure < ONE_ATMOSPHERE*0.8)

			update_icon()

/obj/machinery/airlock_sensor/proc/set_frequency(new_frequency)
	SSradio.remove_object(src, frequency)
	frequency = new_frequency
	radio_connection = SSradio.add_object(src, frequency, RADIO_AIRLOCK)

/obj/machinery/airlock_sensor/Initialize()
	. = ..()
	set_frequency(frequency)
	start_processing()

/obj/machinery/airlock_sensor/New()
	..()

/obj/machinery/airlock_sensor/airlock_interior
	command = "cycle_interior"

/obj/machinery/airlock_sensor/airlock_exterior
	command = "cycle_exterior"

/obj/machinery/access_button
	icon = 'icons/obj/airlock_machines.dmi'
	icon_state = "access_button_standby"
	name = "access button"

	anchored = TRUE
	power_channel = ENVIRON

	var/master_tag
	var/frequency = 1449
	var/command = "cycle"

	var/datum/radio_frequency/radio_connection

	var/on = 1


/obj/machinery/access_button/update_icon_state()
	if(on)
		icon_state = "access_button_standby"
	else
		icon_state = "access_button_off"

/obj/machinery/access_button/attackby(obj/item/I, mob/user, params)
	. = ..()

	if(istype(I, /obj/item/card/id))
		attack_hand(user)

/obj/machinery/access_button/attack_hand(mob/living/user)
	. = ..()
	if(.)
		return
	if(!allowed(user))
		to_chat(user, span_warning("Access Denied"))

	else if(radio_connection)
		var/datum/signal/signal = new
		signal.transmission_method = 1 //radio signal
		signal.data["tag"] = master_tag
		signal.data["command"] = command

		radio_connection.post_signal(src, signal, range = AIRLOCK_CONTROL_RANGE, filter = RADIO_AIRLOCK)
	flick("access_button_cycle", src)


/obj/machinery/access_button/proc/set_frequency(new_frequency)
	SSradio.remove_object(src, frequency)
	frequency = new_frequency
	radio_connection = SSradio.add_object(src, frequency, RADIO_AIRLOCK)


/obj/machinery/access_button/Initialize()
	. = ..()
	set_frequency(frequency)


/obj/machinery/access_button/New()
	..()

/obj/machinery/access_button/airlock_interior
	frequency = 1379
	command = "cycle_interior"

/obj/machinery/access_button/airlock_exterior
	frequency = 1379
	command = "cycle_exterior"
