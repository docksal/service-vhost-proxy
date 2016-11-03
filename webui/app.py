from werkzeug.wsgi import DispatcherMiddleware
from werkzeug.serving import run_simple
from flask import Flask, render_template, redirect, url_for
from docker import Client

# Debug
import pprint

webui = Flask(__name__)

app = DispatcherMiddleware(None, {
    '/webui': webui
})

cli = Client(base_url='unix://var/run/docker.sock')

def hbytes(num):
    for x in ['bytes','KB','MB','GB']:
        if num < 1024.0:
            return "%3.1f%s" % (num, x)
        num /= 1024.0
    return "%3.1f%s" % (num, 'TB')

@webui.route('/')
def containers():
    containers = cli.containers(False, True)
    grouped_containers = {
      'docksal': {},
      'projects': {},
      'other': {}
    }
    for container in containers:
        if container['State'] == 'running':
            stats = cli.stats(container['Id'], True, False)
            cpu_delta = stats['cpu_stats']['cpu_usage']['total_usage'] -  stats['precpu_stats']['cpu_usage']['total_usage']
            system_delta = stats['cpu_stats']['system_cpu_usage'] - stats['precpu_stats']['system_cpu_usage']
            container['Stats'] = {
                'cpu': '{0:.2f}'.format(cpu_delta / system_delta * 100),
                'memory': '{0}'.format(hbytes(stats['memory_stats']['usage']))
            }
        if 'io.docksal.group' in container['Labels']:
            grouped_containers['docksal'][container['Id']] = container
        elif 'com.docker.compose.project' in container['Labels']:
            if container['Labels']['com.docker.compose.project'] not in grouped_containers['projects']:
                grouped_containers['projects'][container['Labels']['com.docker.compose.project']] = {}
            grouped_containers['projects'][container['Labels']['com.docker.compose.project']][container['Id']] = container
        else:
            grouped_containers['other'][container['Id']] = container
    return render_template('containers.html', containers = grouped_containers)

@webui.route('/networks')
def networks():
    return render_template('networks.html', networks = cli.networks())

@webui.route('/logs/<container_id>')
def logs(container_id):
    log = cli.logs(container_id, True, True, False, False, 200)
    return render_template('logs.html', container_id = container_id, log = log.decode('utf-8'))

@webui.route('/inspect/container/<container_id>')
def inspect_container(container_id):
    inspect = cli.inspect_container(container_id)
    return render_template('inspect_container.html', container_id = container_id, inspect = inspect)

@webui.route('/remove/container/<container_id>')
def remove_container(container_id):
    cli.remove_container(container_id, False, False, True)
    return redirect(url_for('containers'), code = 302)

@webui.route('/inspect/network/<network_id>')
def inspect_network(network_id):
    inspect = cli.inspect_network(network_id)
    return render_template('inspect_network.html', network_id = network_id, inspect = inspect)

if __name__ == '__main__':
    run_simple('127.0.0.1', 5000, app, use_reloader=False, use_debugger=False, use_evalex=False)
