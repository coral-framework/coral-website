// Loads all Bootstrap javascripts
//= require bootstrap/affix
//= require bootstrap/collapse
//= require bootstrap/dropdown
//= require bootstrap/scrollspy
//= require bootstrap/tooltip
//= require bootstrap/transition
//= require _anchorjump
//= require _hotkeys
//= require _typeahead
//= require _hogan-2.0.0

String.prototype.toTitleCase = function () {
  return this.replace(/\w\S*/g, function(txt){
    return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();});
};

$(document).bind('keypress', 's', function(e) {
  $(".searchbox").focus();
  e.preventDefault();
});

$(document).ready(function() {
  // enable dropdown menus
  $('.dropdown-toggle').dropdown();

  // enable tooltips for TypeKind labels
  $('.tk').tooltip();

  // enhanced anchor jumps
  $('a[href^="#"]').anchorjump();
  setTimeout(function() {
    if(location.hash) $.anchorjump(location.hash);
  }, 1);

  var navbarHeight = $('.navbar').outerHeight();

  // affix TOC
  $('#toc').affix({
    offset: {
      top: function() {
        return (this.top = $('#toc').offset().top - navbarHeight);
      },
      bottom: function () {
        return (this.bottom = $('.footer').outerHeight(true))
      }
    }
  })

  // enable TOC scroll spy
  $('body').scrollspy({ target: '#toc', offset: 120 });

  // searchbox typeahead
  var autocompletedDatum = null;
  $('.searchbox').typeahead({
    name: 'coral',
    prefetch: {
      ttl: 1, // in milliseconds
      url: '/index.json',
      filter: function(index) {
        var entries = []
        // API
        for( var i = 0; i < index.modules.length; ++i ) {
          var module = index.modules[i];
          module.kind = 'Module';
          module.value = module.name;
          module.tokens = module.name.split('.').concat(module.name);
          module.url = '/api/modules/' + module.name.replace(/\./g, '/');
          entries.push(module);
          for( var j = 0; j < module.types.length; ++j ) {
            var t = module.types[j];
            t.kind = t.kind.toTitleCase();
            t.value = t.name;
            t.tokens = t.name.split('.').concat(t.name);
            t.url = '/api/modules/' + t.name.replace(/\./g, '/');
            entries.push(t);
            if( !t.members ) continue;
            for( var k = 0; k < t.members.length; ++k ) {
              var m = t.members[k];
              m.kind = m.kind.toTitleCase();
              m.parent = t.name;
              m.value = m.name + ' ' + t.name;
              m.tokens = t.name.split('.').concat(m.name);
              m.url = '/api/modules/' + t.name.replace(/\./g, '/') + '#' + m.name;
              entries.push(m);
            }
          }
        }
        // Pages
        for( var i = 0; i < index.pages.length; ++i ) {
          var p = index.pages[i];
          p.kind = 'Article';
          p.value = p.name;
          p.tokens = p.name.split(' ');
          entries.push(p);
          if( !p.sections ) continue;
          for( var j = 0; j < p.sections.length; ++j ) {
            var s = p.sections[j];
            s.kind = 'Article';
            s.parent = p.name;
            s.value = s.name + ' ' + p.name;
            s.tokens = p.name.split(' ').concat( s.name.split(' ') );
            s.url = p.url + '#' + s.id;
            entries.push(s);
          }
        }
        return entries
      },
    },
    template: '\
  <p class="kind">{{kind}}</p> \
  {{#parent}} \
    <p class="name">{{name}} <span class="origin">{{parent}}</span></p> \
  {{/parent}} \
  {{^parent}}<p class="name">{{value}}</p>{{/parent}} \
  <p class="desc">{{desc}}</p>',
    engine: Hogan,
  }).on("typeahead:selected", function($e, datum) {
    window.location = datum.url;
  }).on("typeahead:autocompleted", function($e, datum) {
    autocompletedDatum = datum;
  }).bind('keydown', 'return', function(e) {
    if(autocompletedDatum)
      window.location = autocompletedDatum.url;
  });

});
