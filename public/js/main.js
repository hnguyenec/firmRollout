$(document).ready(
	function() { 
		$('body').bootstrapMaterialDesign(); 

		$('a.start').click(function(e){
			e.preventDefault();
			
			var html = '<li>Checking folder structure... <span class="ol-li"><i class="fas fa-spinner fa-pulse"></i></span></li>';
			var request = {
                url: "./api/essentialChecks.cfc",
                type: "GET",
                dataType: "json",
                async: true,
                beforeSend: function(){
                	if (!$('div.footer').is(":visible")) {
						$('div.footer').show();
                	}

                    $('div.footer ol').append(html);
                },
                data: {
                    method: "initializeProcess"
                }
            }

            $.ajax(request)
            .done(function(response){
            	var msgClass = '';
            	if (response.result) {
            		$('div.footer ol span.ol-li i').last().attr('class', 'far fa-check-circle');
            		msgClass = 'ok';
            	} else {
            		$('div.footer ol span.ol-li i').last().attr('class', 'far fa-times-circle');	
            		msgClass = 'error';
            	}

            	var html = '<ul>';
            	for(var i=0; i< response.messages.length; i++) {
            		html += response.messages[i].message;
            	}
            	html += '</ul>';

            	$('div.footer ol li').last().append('<ul>' + html + '</ul>');
            })
            .fail(function(requestObject, error, errorThrown){
            	$('div.footer ol span.ol-li i').last().attr('class', 'far fa-times-circle');
            	$('div.footer ol li').last().append('<ul><li class="error">[ ' + error + ' ]: ' + (errorThrown.message || errorThrown) + '</li></ul>');
            })
            .always(function(res) {
                if (_.has(res, "next") && _.size(res.next) ) {
                    var html2 = '<li>Loading step: <b>' + res.next.name + '</b>... <span class="ol-li"><i class="fas fa-spinner fa-pulse"></i></span></li>';
                    $('div.footer ol').append(html2);
                    _renderStep(res);
                }
            })
			return false;
		})


        function _renderStep(response) {
            var request = {
                url: "./api/loadStep.cfc",
                type: "POST",
                //dataType: "application/json; charset=utf-8",
                async: true,
                beforeSend: function(){
                    if (!$('div.footer').is(":visible")) {
                        $('div.footer').show();
                    }

                    //$('div.footer ol').append(html);
                },
                headers: {
                    'Authorization': response.next.token,
                },
                data: {
                    method: "view"
                }
            }

            $.ajax(request)
            .done(function(response){
                //debugger;
                $(".step-container").html(response);
            })
            .fail(function(requestObject, error, errorThrown){
                debugger;
            })
            
        }
	}
);