class_name NotificationService
extends RefCounted
## FaillesCheck — notifications réelles du téléphone (Android et iOS) via le
## greffon NotificationSchedulerPlugin. Sur ordinateur, tout est ignoré :
## l'application reste parfaitement fonctionnelle sans le greffon.

const SINGLETON_NAME := "NotificationSchedulerPlugin"
const CHANNEL_ID := "faillescheck_alerts"
const CHANNEL_NAME := "Alertes de vulnérabilités"

static var _scheduler: NotificationScheduler = null
static var _ready := false

## À appeler une fois au démarrage (DataStore). Sans effet sur ordinateur.
static func setup(parent: Node) -> void:
	if not Engine.has_singleton(SINGLETON_NAME):
		return
	if _scheduler != null:
		return
	_scheduler = NotificationScheduler.new()
	_scheduler.name = "NotificationScheduler"
	parent.add_child(_scheduler)
	_scheduler.initialization_completed.connect(_on_initialized)
	_scheduler.initialize()

static func _on_initialized() -> void:
	if _scheduler == null:
		return
	_ready = true
	var channel := NotificationChannel.new()
	channel.set_id(CHANNEL_ID)
	channel.set_name(CHANNEL_NAME)
	channel.set_description("Nouvelles failles critiques concernant vos logiciels suivis.")
	channel.set_importance(NotificationChannel.Importance.HIGH)
	channel.set_badge_enabled(true)
	_scheduler.create_notification_channel(channel)
	if not _scheduler.has_post_notifications_permission():
		_scheduler.request_post_notifications_permission()

## Vrai seulement sur mobile, avec le greffon installé et prêt.
static func available() -> bool:
	return _scheduler != null and _ready

## Met à jour le badge de l'icône de l'application.
static func set_badge(count: int) -> void:
	if not available():
		return
	_scheduler.set_badge_count(max(0, count))

## Affiche une vraie notification système.
static func notify(title: String, body: String) -> void:
	if not available():
		return
	var data := NotificationData.new()
	data.set_id(int(Time.get_unix_time_from_system()) % 100000)
	data.set_channel_id(CHANNEL_ID)
	data.set_title(title)
	data.set_content(body)
	data.set_delay(0)
	_scheduler.schedule(data)
