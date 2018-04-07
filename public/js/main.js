$(document).ready(
	function() { 
		$('body').bootstrapMaterialDesign(); 

		$('a.start').click(function(e){
			e.preventDefault();
			
			var request = {
                url: "./api/essentialChecks.cfc",
                type: "GET",
                dataType: "json",
                async: true,
                beforeSend: function(){
                	if (!$('div.footer').is(":visible")) {
						$('div.footer').show();
                	}

                    $('div.footer ol').append('<li>Checking folder structure... <span class="ol-li"><i class="fas fa-spinner fa-pulse"></i></span></li>');
                },
                data: {
                    method: "initializeProcess"
                }
            }

            $.ajax(request)
            .done(function(response){

            })
            .fail(function(requestObject, error, errorThrown){
            	
            })
			return false;
		})
	}
);