function Header(heading)
	if heading.level == 3 then
		heading.level = 2
		return heading
	elseif heading.level == 2 then
		heading.level = 1
		return heading
	end
	return heading
end
