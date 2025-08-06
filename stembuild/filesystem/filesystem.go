package filesystem

//go:generate go run github.com/maxbrunsfeld/counterfeiter/v6 -generate

//counterfeiter:generate . FileSystem
type FileSystem interface {
	GetAvailableDiskSpace(path string) (uint64, error)
}
