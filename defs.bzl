Alert = provider(fields = ["job", "file"])

def _alert(ctx):
    """Builds an {name}.yaml file with all groups and alerts."""
    content = """groups:
"""
    header = ctx.actions.declare_file("{}_header.yaml".format(ctx.attr.name))
    ctx.actions.write(header, content)

    files = []
    for group in ctx.attr.groups:
        files.extend(group[DefaultInfo].files.to_list())

    alert = ctx.actions.declare_file("{}.yaml".format(ctx.attr.name))
    ctx.actions.run_shell(
        outputs = [alert],
        command = "cat $@ > {}".format(alert.path),
        inputs = [header] + files,
        arguments = [f.path for f in [header] + files],
    )

    return [
        DefaultInfo(files = depset([alert])),
    ]

alert = rule(
    implementation = _alert,
    attrs = {
        "groups": attr.label_list(),
    },
)

def _alert_group(ctx):
    """Builds an alert yaml snippet with a full alert group."""

    content = """
 -name: {}
  rules:
""".format(ctx.attr.group_name)
    header = ctx.actions.declare_file("{}_header.yaml".format(ctx.attr.name))
    ctx.actions.write(header, content)

    files = []
    for alert in ctx.attr.alerts:
        files.append(alert[Alert].file)

    alert_group = ctx.actions.declare_file("{}.yaml".format(ctx.attr.name))
    ctx.actions.run_shell(
        outputs = [alert_group],
        command = "cat $@ > {}".format(alert_group.path),
        inputs = files + [header],
        arguments = [f.path for f in [header] + files],
    )

    return [
        DefaultInfo(files = depset([alert_group])),
    ]

alert_group = rule(
    implementation = _alert_group,
    attrs = {
        "alerts": attr.label_list(providers = [Alert]),
        "group_name": attr.string(mandatory = True),
    },
)

def _alert_many_restarts(ctx):
    """Create an alert for many restarts."""
    alert_file = ctx.actions.declare_file("{}.yaml".format(ctx.attr.name))
    ctx.actions.expand_template(
        template = ctx.file._template,
        output = alert_file,
        substitutions = {
            "JOB": ctx.attr.job,
            "RANGE": ctx.attr.time_range,
            "THRESHOLD": str(ctx.attr.threshold),
            "HOLD": ctx.attr.hold,
            "SEVERITY": ctx.attr.severity,
        },
    )
    return [
        Alert(job = ctx.attr.job, file = alert_file),
        DefaultInfo(files = depset([alert_file])),
    ]

alert_many_restarts = rule(
    attrs = {
        "_template": attr.label(
            default = "@rules_prom//:templates/many_restarts",
            allow_single_file = True,
        ),
        "job": attr.string(mandatory = True),
        "time_range": attr.string(default = "1h"),
        "threshold": attr.int(default = 3),
        "hold": attr.string(default = "10m"),
        "severity": attr.string(default = "ticket"),
    },
    implementation = _alert_many_restarts,
)
