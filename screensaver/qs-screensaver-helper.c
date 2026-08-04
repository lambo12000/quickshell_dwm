/* qs-screensaver-helper - org.freedesktop.ScreenSaver inhibit sink for quickshell.
 *
 * Owns the well known name, records every live Inhibit, and prints the full
 * inhibitor list as one line of minified JSON on stdout whenever it changes.
 * The X screensaver is never touched here; quickshell decides what to do with
 * the list.  See LICENSE file for copyright and license details. */
#include <errno.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/prctl.h>
#include <unistd.h>

#include <systemd/sd-bus.h>
#include <systemd/sd-event.h>

#define BUSNAME "org.freedesktop.ScreenSaver"
#define IFACE   "org.freedesktop.ScreenSaver"

struct inhibitor {
	uint32_t cookie;
	char *sender;
	char *app;
	char *reason;
};

static struct inhibitor *inhibitors;
static size_t ninhibitors;
static size_t cinhibitors;
static sd_event *loop;

static void
print_json_string(const char *s)
{
	const unsigned char *p;

	fputc('"', stdout);
	for (p = (const unsigned char *)s; *p; p++) {
		if (*p == '"' || *p == '\\')
			printf("\\%c", *p);
		else if (*p < 0x20)
			printf("\\u%04x", *p);
		else
			fputc(*p, stdout);
	}
	fputc('"', stdout);
}

/* The sole stdout writer: one full-state line per change, never a delta. */
static void
print_state(void)
{
	size_t i;

	fputs("{\"inhibitors\":[", stdout);
	for (i = 0; i < ninhibitors; i++) {
		if (i)
			fputc(',', stdout);
		printf("{\"cookie\":%u,\"app\":", inhibitors[i].cookie);
		print_json_string(inhibitors[i].app);
		fputs(",\"reason\":", stdout);
		print_json_string(inhibitors[i].reason);
		fputc('}', stdout);
	}
	fputs("]}\n", stdout);
	fflush(stdout);

	/* Reader is gone; nothing left to serve. */
	if (ferror(stdout))
		exit(0);
}

static int
cookie_in_use(uint32_t cookie)
{
	size_t i;

	for (i = 0; i < ninhibitors; i++)
		if (inhibitors[i].cookie == cookie)
			return 1;
	return 0;
}

/* Returns 0 only if every cookie is somehow taken. */
static uint32_t
alloc_cookie(void)
{
	static uint32_t next;
	uint32_t tries;

	for (tries = 0; tries < UINT32_MAX; tries++) {
		if (++next == 0)
			next = 1;
		if (!cookie_in_use(next))
			return next;
	}
	return 0;
}

/* Returns the new cookie, or 0 on failure. */
static uint32_t
add_inhibitor(const char *sender, const char *app, const char *reason)
{
	struct inhibitor *ih, *grown;
	uint32_t cookie;
	size_t cap;

	if (!(cookie = alloc_cookie()))
		return 0;

	if (ninhibitors == cinhibitors) {
		cap = cinhibitors ? cinhibitors * 2 : 8;
		if (!(grown = realloc(inhibitors, cap * sizeof(*grown))))
			return 0;
		inhibitors = grown;
		cinhibitors = cap;
	}

	ih = &inhibitors[ninhibitors];
	ih->cookie = cookie;
	ih->sender = strdup(sender);
	ih->app = strdup(app);
	ih->reason = strdup(reason);
	if (!ih->sender || !ih->app || !ih->reason) {
		free(ih->sender);
		free(ih->app);
		free(ih->reason);
		return 0;
	}
	ninhibitors++;
	return cookie;
}

static void
remove_at(size_t i)
{
	free(inhibitors[i].sender);
	free(inhibitors[i].app);
	free(inhibitors[i].reason);
	memmove(&inhibitors[i], &inhibitors[i + 1],
	        (ninhibitors - i - 1) * sizeof(*inhibitors));
	ninhibitors--;
}

static int
remove_cookie(uint32_t cookie)
{
	size_t i;

	for (i = 0; i < ninhibitors; i++)
		if (inhibitors[i].cookie == cookie) {
			remove_at(i);
			return 1;
		}
	return 0;
}

static int
remove_sender(const char *sender)
{
	size_t i;
	int removed;

	removed = 0;
	for (i = 0; i < ninhibitors;)
		if (!strcmp(inhibitors[i].sender, sender)) {
			remove_at(i);
			removed = 1;
		} else
			i++;
	return removed;
}

static int
method_inhibit(sd_bus_message *m, void *userdata, sd_bus_error *ret_error)
{
	const char *app, *reason, *sender;
	uint32_t cookie;
	int r;

	(void)userdata;

	if ((r = sd_bus_message_read(m, "ss", &app, &reason)) < 0)
		return r;

	sender = sd_bus_message_get_sender(m);
	if (!(cookie = add_inhibitor(sender ? sender : "", app, reason)))
		return sd_bus_error_set(ret_error, SD_BUS_ERROR_NO_MEMORY,
		                        "Cannot record inhibitor");

	r = sd_bus_reply_method_return(m, "u", cookie);
	print_state();
	return r;
}

static int
method_uninhibit(sd_bus_message *m, void *userdata, sd_bus_error *ret_error)
{
	uint32_t cookie;
	int r, removed;

	(void)userdata;
	(void)ret_error;

	if ((r = sd_bus_message_read(m, "u", &cookie)) < 0)
		return r;

	/* An unknown cookie is not an error: some clients treat one as fatal. */
	removed = remove_cookie(cookie);
	r = sd_bus_reply_method_return(m, NULL);
	if (removed)
		print_state();
	return r;
}

static int
method_noop(sd_bus_message *m, void *userdata, sd_bus_error *ret_error)
{
	(void)userdata;
	(void)ret_error;

	return sd_bus_reply_method_return(m, NULL);
}

static int
method_get_active(sd_bus_message *m, void *userdata, sd_bus_error *ret_error)
{
	(void)userdata;
	(void)ret_error;

	return sd_bus_reply_method_return(m, "b", 0);
}

static int
method_set_active(sd_bus_message *m, void *userdata, sd_bus_error *ret_error)
{
	int active, r;

	(void)userdata;
	(void)ret_error;

	if ((r = sd_bus_message_read(m, "b", &active)) < 0)
		return r;

	/* We never blank the screen ourselves, so the request is refused. */
	return sd_bus_reply_method_return(m, "b", 0);
}

static int
method_zero(sd_bus_message *m, void *userdata, sd_bus_error *ret_error)
{
	(void)userdata;
	(void)ret_error;

	return sd_bus_reply_method_return(m, "u", (uint32_t)0);
}

static int
method_unsupported(sd_bus_message *m, void *userdata, sd_bus_error *ret_error)
{
	(void)m;
	(void)userdata;

	return sd_bus_error_set(ret_error, SD_BUS_ERROR_NOT_SUPPORTED,
	                        "Throttling is not supported");
}

static const sd_bus_vtable screensaver_vtable[] = {
	SD_BUS_VTABLE_START(0),
	SD_BUS_METHOD_WITH_ARGS("Inhibit",
	        SD_BUS_ARGS("s", application_name, "s", reason_for_inhibit),
	        SD_BUS_RESULT("u", cookie),
	        method_inhibit, SD_BUS_VTABLE_UNPRIVILEGED),
	SD_BUS_METHOD_WITH_ARGS("UnInhibit",
	        SD_BUS_ARGS("u", cookie),
	        SD_BUS_NO_RESULT,
	        method_uninhibit, SD_BUS_VTABLE_UNPRIVILEGED),
	SD_BUS_METHOD_WITH_ARGS("Lock",
	        SD_BUS_NO_ARGS, SD_BUS_NO_RESULT,
	        method_noop, SD_BUS_VTABLE_UNPRIVILEGED),
	SD_BUS_METHOD_WITH_ARGS("SimulateUserActivity",
	        SD_BUS_NO_ARGS, SD_BUS_NO_RESULT,
	        method_noop, SD_BUS_VTABLE_UNPRIVILEGED),
	SD_BUS_METHOD_WITH_ARGS("GetActive",
	        SD_BUS_NO_ARGS,
	        SD_BUS_RESULT("b", active),
	        method_get_active, SD_BUS_VTABLE_UNPRIVILEGED),
	SD_BUS_METHOD_WITH_ARGS("SetActive",
	        SD_BUS_ARGS("b", active),
	        SD_BUS_RESULT("b", accepted),
	        method_set_active, SD_BUS_VTABLE_UNPRIVILEGED),
	SD_BUS_METHOD_WITH_ARGS("GetActiveTime",
	        SD_BUS_NO_ARGS,
	        SD_BUS_RESULT("u", seconds),
	        method_zero, SD_BUS_VTABLE_UNPRIVILEGED),
	SD_BUS_METHOD_WITH_ARGS("GetSessionIdleTime",
	        SD_BUS_NO_ARGS,
	        SD_BUS_RESULT("u", seconds),
	        method_zero, SD_BUS_VTABLE_UNPRIVILEGED),
	SD_BUS_METHOD_WITH_ARGS("Throttle",
	        SD_BUS_ARGS("s", application_name, "s", reason_for_throttle),
	        SD_BUS_RESULT("u", cookie),
	        method_unsupported, SD_BUS_VTABLE_UNPRIVILEGED),
	SD_BUS_METHOD_WITH_ARGS("UnThrottle",
	        SD_BUS_ARGS("u", cookie),
	        SD_BUS_NO_RESULT,
	        method_unsupported, SD_BUS_VTABLE_UNPRIVILEGED),
	SD_BUS_VTABLE_END
};

static int
on_owner_changed(sd_bus_message *m, void *userdata, sd_bus_error *ret_error)
{
	const char *name, *old_owner, *new_owner;
	int r;

	(void)userdata;
	(void)ret_error;

	if ((r = sd_bus_message_read(m, "sss", &name, &old_owner, &new_owner)) < 0)
		return r;

	/* A vanishing owner only means the peer disconnected when the name that
	 * went away is its unique name; otherwise a still-connected client just
	 * released a well-known name and keeps whatever it holds. */
	if (*new_owner == '\0' && *old_owner != '\0' && !strcmp(name, old_owner) &&
	    remove_sender(old_owner))
		print_state();
	return 0;
}

static int
on_name_lost(sd_bus_message *m, void *userdata, sd_bus_error *ret_error)
{
	const char *name;
	int r;

	(void)userdata;
	(void)ret_error;

	if ((r = sd_bus_message_read(m, "s", &name)) < 0)
		return r;

	/* A newer instance replaced us; step aside. */
	if (!strcmp(name, BUSNAME))
		sd_event_exit(loop, 0);
	return 0;
}

static int
on_exit_signal(sd_event_source *s, const struct signalfd_siginfo *si, void *userdata)
{
	(void)s;
	(void)si;
	(void)userdata;

	return sd_event_exit(loop, 0);
}

int
main(void)
{
	sd_bus *bus;
	sigset_t mask;
	int r;

	setvbuf(stdout, NULL, _IOLBF, 0);

	/* SIGPIPE stays fatal on purpose: a dead reader means a dead helper. */
	prctl(PR_SET_PDEATHSIG, SIGTERM);
	if (getppid() == 1)
		return 0;

	if ((r = sd_bus_open_user(&bus)) < 0) {
		fprintf(stderr, "cannot connect to session bus: %s\n", strerror(-r));
		return 1;
	}

	/* Clients disagree on which path the interface lives at; serve both. */
	if ((r = sd_bus_add_object_vtable(bus, NULL, "/ScreenSaver", IFACE,
	                                  screensaver_vtable, NULL)) < 0 ||
	    (r = sd_bus_add_object_vtable(bus, NULL, "/org/freedesktop/ScreenSaver", IFACE,
	                                  screensaver_vtable, NULL)) < 0) {
		fprintf(stderr, "cannot export interface: %s\n", strerror(-r));
		return 1;
	}

	if ((r = sd_bus_match_signal(bus, NULL, "org.freedesktop.DBus",
	                             "/org/freedesktop/DBus", "org.freedesktop.DBus",
	                             "NameOwnerChanged", on_owner_changed, NULL)) < 0 ||
	    (r = sd_bus_match_signal(bus, NULL, "org.freedesktop.DBus",
	                             "/org/freedesktop/DBus", "org.freedesktop.DBus",
	                             "NameLost", on_name_lost, NULL)) < 0) {
		fprintf(stderr, "cannot install match: %s\n", strerror(-r));
		return 1;
	}

	/* Replace flags keep a stale orphan from wedging the name forever. */
	if ((r = sd_bus_request_name(bus, BUSNAME, SD_BUS_NAME_ALLOW_REPLACEMENT |
	                             SD_BUS_NAME_REPLACE_EXISTING)) < 0) {
		fprintf(stderr, "cannot acquire %s: %s\n", BUSNAME, strerror(-r));
		return 1;
	}

	if ((r = sd_event_default(&loop)) < 0 ||
	    (r = sd_bus_attach_event(bus, loop, SD_EVENT_PRIORITY_NORMAL)) < 0) {
		fprintf(stderr, "cannot set up event loop: %s\n", strerror(-r));
		return 1;
	}

	/* Without this the loop stays alive on the signal sources alone, leaving
	 * a helper that can never serve another Inhibit and never restarts. */
	sd_bus_set_exit_on_disconnect(bus, 1);

	sigemptyset(&mask);
	sigaddset(&mask, SIGTERM);
	sigaddset(&mask, SIGINT);
	sigprocmask(SIG_BLOCK, &mask, NULL);
	if ((r = sd_event_add_signal(loop, NULL, SIGTERM, on_exit_signal, NULL)) < 0 ||
	    (r = sd_event_add_signal(loop, NULL, SIGINT, on_exit_signal, NULL)) < 0) {
		fprintf(stderr, "cannot watch signals: %s\n", strerror(-r));
		return 1;
	}

	/* Marks us live and clears whatever the previous instance left behind. */
	print_state();

	if ((r = sd_event_loop(loop)) < 0) {
		fprintf(stderr, "event loop failed: %s\n", strerror(-r));
		return 1;
	}
	return 0;
}
