(function ($) {
  $(document).ready(function () {
    $('#projects .project').each(function(i, element) {
      var project = $(element);
      var services = $(element).find('#' + $(element).attr('id') + '-content .service');

      project.find('#' + $(element).attr('id') + '-header .panel-title a').append('<span class="badge">' + services.length + ' services</span>');

      var project_root = $(services).find('.project-root');
      if (project_root.length > 0) {
        var roots = {};
        project_root.each(function (i, element) {
          var root = $(element).text().replace('Project Root: ', '');
          roots[root] = root;
        });
        project.find('#' + project.attr('id') + '-header .panel-title').append('<button class="btn btn-info project-root-popover" role="button" data-toggle="popover" data-placement="bottom" title="Project roots" data-content="' + Object.keys(roots).join("\r\n") + '">Project roots</a>');
      }

      var virtual_host = $(services).find('.virtual-host');
      if (virtual_host.length > 0) {
        var hosts = {};
        virtual_host.each(function (i, element) {
          var host = $(element).text().replace('Virtual Host: ', '');
          hosts[host] = host;
        });
        project.find('#' + project.attr('id') + '-header .panel-title').append('<button class="btn btn-info project-root-popover" role="button" data-toggle="popover" data-placement="bottom" title="Hosts" data-content="' + Object.keys(hosts).join("\r\n") + '">Hosts</a>');
      }

      var running = $(services).filter('.running').length;
      var not_running = $(services).filter('.not-running').length;

      if (running == 0 && not_running > 0) {
        project.find('#' + project.attr('id') + '-header .panel-title').append($('<span class="pull-right glyphicon glyphicon-remove-sign text-danger"></span>'));
      }
      else if (running > 0 && not_running == 0) {
        project.find('#' + project.attr('id') + '-header .panel-title').append($('<span class="pull-right glyphicon glyphicon-ok-sign text-success"></span>'));
      }
      else if (running > 0 && not_running > 0) {
        project.find('#' + project.attr('id') + '-header .panel-title').append($('<span class="pull-right glyphicon glyphicon-exclamation-sign text-warning"></span>'));
      }
    });

    $('[data-toggle="popover"]').popover();
  });
})(jQuery)
