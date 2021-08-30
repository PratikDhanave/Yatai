package transformersv1

import (
	"context"

	jujuerrors "github.com/juju/errors"

	"github.com/bentoml/yatai/schemas/modelschemas"

	"github.com/pkg/errors"

	"github.com/bentoml/yatai/api-server/models"
	"github.com/bentoml/yatai/api-server/services"
	"github.com/bentoml/yatai/schemas/schemasv1"
)

func ToOrganizationSchema(ctx context.Context, org *models.Organization) (*schemasv1.OrganizationSchema, error) {
	if org == nil {
		return nil, nil
	}
	ss, err := ToOrganizationSchemas(ctx, []*models.Organization{org})
	if err != nil {
		return nil, errors.Wrap(err, "ToOrganizationSchemas")
	}
	return ss[0], nil
}

func ToOrganizationFullSchema(ctx context.Context, org *models.Organization) (*schemasv1.OrganizationFullSchema, error) {
	if org == nil {
		return nil, nil
	}
	s, err := ToOrganizationSchema(ctx, org)
	if err != nil {
		return nil, errors.Wrap(err, "ToOrganizationSchema")
	}
	var config **modelschemas.OrganizationConfigSchema
	currentUser, err := services.GetCurrentUser(ctx)
	if err != nil {
		return nil, errors.Wrap(err, "get current user")
	}
	if err = services.MemberService.CanUpdate(ctx, &services.OrganizationMemberService, currentUser.ID, org.ID); err != nil {
		if !jujuerrors.IsForbidden(err) {
			return nil, err
		}
	} else {
		config = &org.Config
	}
	return &schemasv1.OrganizationFullSchema{
		OrganizationSchema: *s,
		Config:             config,
	}, nil
}

func ToOrganizationSchemas(ctx context.Context, orgs []*models.Organization) ([]*schemasv1.OrganizationSchema, error) {
	res := make([]*schemasv1.OrganizationSchema, 0, len(orgs))
	for _, org := range orgs {
		creatorSchema, err := GetAssociatedCreatorSchema(ctx, org)
		if err != nil {
			return nil, errors.Wrap(err, "GetAssociatedCreatorSchema")
		}
		res = append(res, &schemasv1.OrganizationSchema{
			ResourceSchema: ToResourceSchema(org),
			Creator:        creatorSchema,
			Description:    org.Description,
		})
	}
	return res, nil
}

type IOrganizationAssociate interface {
	services.IOrganizationAssociate
	models.IResource
}

func GetAssociatedOrganizationSchema(ctx context.Context, associate IOrganizationAssociate) (*schemasv1.OrganizationSchema, error) {
	user, err := services.OrganizationService.GetAssociatedOrganization(ctx, associate)
	if err != nil {
		return nil, errors.Wrapf(err, "get %s %s associated organization", associate.GetResourceType(), associate.GetName())
	}
	userSchema, err := ToOrganizationSchema(ctx, user)
	if err != nil {
		return nil, errors.Wrap(err, "ToOrganizationSchema")
	}
	return userSchema, nil
}