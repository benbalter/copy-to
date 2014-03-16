$ ->
  $(".index form").submit (e) ->
    e.preventDefault()
    nwo = $("#repo").val().replace("https://github.com/", "")
    document.location.href = document.location.href + nwo
    false
