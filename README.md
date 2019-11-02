# jafax.org

Website framework for Jafax.org's website.

The app name, buyo, is named after a traditional style of Japanese dancing
called Nihon Buyō, a form that is meant for entertainment. As the framework
for this is based on Perl's excellent Dancer framework, and JAFAX is an
event to entertain (and educate) about Japanese culture through Anim&eacute; and
other activities, it seems to fit as a theme.

## Configuration

Buyo uses two different configurations:

1. Dancer2 configuration with environments using YAML, JSON, or Apache styled configuration files
   - config.yml
   - environments/deployment.yml
   - environments/production.yml
1. An INI file in conf.d to configure specific elements of the application code
   - conf.d/config.ini

### Dancer2 Configuration

The Dancer2 configuration covers the plugins and how Dancer should run. A minimal Dancer2 configuration follows:

```yaml
appname: "buyo"
port: 5000
host: localhost
behind_proxy: 1
logger: file
log: core
layout: "main"
charset: "UTF-8"
template: "template_toolkit"

# debugging
warnings: 0
show_errors: 0
startup_info: 0
traces: 0

engines:
  template:
    template_toolkit:
      start_tag: '[%'
      end_tag:   '%]'
      debug:     0

engines:
  logger:
    File:
      log_level: core
```

In a development environment, you'll likely want to enable `warnings`, `show_errors`, `startup_info`, and `traces`. However, in production, you'll want to keep those turned off, as there may be secrets that get logged.

### Application configuration

The INI section needs the following to work:

```ini
[General]
debugging = 1

[Web]
webroot = localhost:5000/
article_mech = JSON
```
