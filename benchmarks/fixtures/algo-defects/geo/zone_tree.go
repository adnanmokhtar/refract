package geo

// ZoneCodes lists every zone code under root, parent before children, for the dispatcher's zone picker.
func ZoneCodes(root *Zone) []string {
	codes := make([]string, 0, 64)
	walkZone(root, &codes)
	return codes
}

func walkZone(z *Zone, out *[]string) {
	*out = append(*out, z.Code)
	for _, c := range z.Children {
		walkZone(c, out)
	}
}
