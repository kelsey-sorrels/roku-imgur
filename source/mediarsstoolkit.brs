'**********************************************************
'**  Imgur Application - slideshow and audioplayer
'**  November 2012
'**********************************************************

' ********************************************************************
' ********************************************************************
' ***** Object Constructor
' ***** Object Constructor
' ********************************************************************
' ********************************************************************

Function CreateMediaRSSConnection()As Object
	rss = {
		port: CreateObject("roMessagePort"),
		http: CreateObject("roUrlTransfer"),

		DisplayGalleryViral: DisplayGalleryViral,
		DisplayGalleryHot: DisplayGalleryHot,
		DisplayGalleryPopular: DisplayGalleryPopular,
		DisplayGalleryNewest: DisplayGalleryNewest,
		DisplaySlideShow: DisplaySlideShow,
		GetPhotoListFromFeed: GetPhotoListFromFeed,
		GetCaptionListFromImageHash: GetCaptionListFromImageHash
		}

	return rss
End Function

Function DisplaySetup(port as object)
	slideshow = CreateObject("roSlideShow")
	slideshow.SetMessagePort(port)
	' shrink pictures by 5% to show a little bit of border (no overscan)
	slideshow.SetBorderColor("#000000")
	slideshow.SetMaxUpscale(8.0)
	slideshow.SetDisplayMode("scale-to-fit")
	slideshow.SetPeriod(6)
	slideshow.Show()
	return slideshow
End Function


Sub DisplayGalleryViral()
	slideshow = DisplaySetup(m.port)

	photolist=m.GetPhotoListFromFeed("http://imgur.com/gallery/top/day.xml")
	m.DisplaySlideShow(slideshow, photolist)
End Sub

Sub DisplayGalleryHot()
	slideshow = DisplaySetup(m.port)

	photolist=m.GetPhotoListFromFeed("http://imgur.com/gallery/hot/all.xml")
	m.DisplaySlideShow(slideshow, photolist)
End Sub

Sub DisplayGalleryPopular()
	slideshow = DisplaySetup(m.port)

	photolist=m.GetPhotoListFromFeed("http://imgur.com/gallery/hot/time.xml")
	m.DisplaySlideShow(slideshow, photolist)
End Sub

Sub DisplayGalleryNewest()
	slideshow = DisplaySetup(m.port)

	photolist=m.GetPhotoListFromFeed("http://imgur.com/gallery/top/time.xml")
	m.DisplaySlideShow(slideshow, photolist)
End Sub

Function GetPhotoListFromFeed(feed_url) As Object

	print "GetPhotoListFromFeed: ";feed_url
	m.http.SetUrl(feed_url)
	xml=m.http.GetToString()
	data=CreateObject("roXMLElement")
	if not data.Parse(xml) then stop

	pl=CreateObject("roList")
	for each item in data.item
		pl.Push(newPhotoFromXML(m.http, item))
		print "photo title=";pl.Peek().GetTitle()
	next

	return pl

End Function

Function GetCaptionListFromImageHash(hash) As Object
	print "GetCaptionListFromImageHash: ";hash
	url = "http://imgur.com/gallery/" + hash + ".xml"
	m.http.SetUrl(url)
	xml = m.http.GetToString()
	data = CreateObject("roXMLElement")
	if not data.Parse(xml) then stop
	captionList = CreateObject("roList")
	for each item in data.captions.item
		captionList.Push(item.caption.GetText())
	next

	return captionList
End Function

Function newPhotoFromXML(http As Object, xml As Object) As Object
  photo = {http:http, xml:xml, GetURL:pGetURL}
  photo.GetTitle=function():return m.xml.title.GetText():end function
  return photo
End Function


Function pGetURL()
	return "http://imgur.com/" + m.xml.hash.GetText() + m.xml.ext.GetText()
End Function


Function UpdateSlideShow(slideshow, index)
	slideshow.ClearContent()
	slideshow.SetContentList(contentArray)
	slideshow.SetNext(index, true)
	slideshow.Resume()
	slideshow.Pause()
End Function

Sub DisplaySlideShow(slideshow, photolist)
	print "in DisplaySlideShow"
	'using SetContentList()
	contentArray = CreateObject("roArray", photolist.Count(), true)
	for each photo in photolist
		print "---- new DisplaySlideShow photolist loop ----"
		url = photo.GetURL()
		if url<>invalid then
			aa = CreateObject("roAssociativeArray")
			aa.Url = url
			aa.TextOverlayBody = photo.GetTitle()
			aa.CaptionIndex = -1
			aa.Hash = photo.xml.hash.GetText()
			aa.Title = photo.GetTitle()
			contentArray.Push(aa)
			print "PRELOAD TITLE: ";photo.GetTitle()
		end if
	next
	slideshow.SetContentList(contentArray)

	onscreenphoto = 0
	paused = false

waitformsg:
	msg = wait(0, m.port)
	'print "DisplaySlideShow: class of msg: ";type(msg); " type:";msg.gettype()
	'for each x in msg:print x;"=";msg[x]:next
	if msg <> invalid then							'invalid is timed-out
		if type(msg) = "roSlideShowEvent" then
			if msg.isScreenClosed() then
				return
			else if msg.isPlaybackPosition() then
				' Only take action if onscreenphoto has changed
				if onscreenphoto <> msg.GetIndex() then
					onscreenphoto = msg.GetIndex()
					photo = contentArray[onscreenphoto]
					photo.TextOverlayBody = photo.Title
					photo.CaptionIndex = -1
					print "slideshow display: " + Stri(msg.GetIndex())
					UpdateSlideShow(slideshow, onscreenphoto)
				end if
			elseif msg.isPaused() then
				print "paused"
				paused = true
				slideshow.SetTextOverlayIsVisible(true)
				'example button usage during pause:
				'buttons will only be shown in when the slideshow is paused
			elseif msg.isResumed() then
				print "resumed"
				paused = false
				slideshow.SetTextOverlayIsVisible(false)
			elseif msg.isRemoteKeyPressed() then
				'down button pressed?
				if paused and msg.GetIndex() = 3 then
					print "Down button pressed"
					photo = contentArray[onscreenphoto]
					if photo.Captions = invalid then
						photo.TextOverlayBody = "Loading captions..."
						' update slideshow after changing title
						UpdateSlideShow(slideshow, onscreenphoto)
						print "Downloading imgae captions..." + photo.Hash
						photo.Captions = m.GetCaptionListFromImageHash(photo.Hash)
						print "Done."
					end if
					'Update photo description with captions[caption_idx]
					photo.CaptionIndex = (photo.CaptionIndex + 1) MOD photo.Captions.Count()
					print "Updating photo with new caption:" + photo.Captions[photo.CaptionIndex]
					photo.TextOverlayBody = photo.Captions[photo.CaptionIndex]
					' update slideshow after changing title
					UpdateSlideShow(slideshow, onscreenphoto)
					print "setting index to: " + Stri(onscreenphoto)
				else
					print "Remote Key Pressed:";Stri(msg.GetIndex())
				end if
			end if
		end if
	end if
	goto waitformsg
End Sub
